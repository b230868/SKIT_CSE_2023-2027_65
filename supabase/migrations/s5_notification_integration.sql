-- S5 (integration pass): run once in Supabase > SQL Editor,
-- after s5_notification_triggers.sql.
-- Links notifications to applications so a tap opens the right screen,
-- completes the event coverage, and lets students delete notifications.

alter table public.notifications
  add column if not exists application_id uuid
  references public.applications(id) on delete cascade;

drop policy if exists "Users delete own notifications" on public.notifications;
create policy "Users delete own notifications" on public.notifications
  for delete using (user_id = auth.uid());

-- Application approved / rejected (now carries application_id)
create or replace function public.notify_on_application_status() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status <> old.status and new.status in ('approved','rejected') then
    insert into public.notifications (user_id, title, body, type, application_id)
    values (
      new.student_id,
      case when new.status = 'approved' then 'Application approved' else 'Application update' end,
      case when new.status = 'approved'
           then 'Your application was approved. You can now log weekly progress.'
           else 'Your application status changed to ' || new.status || '.' end,
      'application',
      new.id
    );
  end if;
  return new;
end $$;

-- Progress logged (now carries application_id)
create or replace function public.notify_on_progress_logged() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (user_id, title, body, type, application_id)
  values (
    new.student_id,
    'Progress saved',
    'Week ' || new.week_no || ' update recorded at ' || new.progress || '%.',
    'progress',
    new.application_id
  );
  return new;
end $$;

-- New: application submitted
create or replace function public.notify_on_application_submitted() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_title text;
begin
  select title into v_title from public.internships where id = new.internship_id;
  insert into public.notifications (user_id, title, body, type, application_id)
  values (
    new.student_id,
    'Application received',
    'Your application for ' || coalesce(v_title, 'the internship') || ' was submitted.',
    'application',
    new.id
  );
  return new;
end $$;

drop trigger if exists on_application_submitted on public.applications;
create trigger on_application_submitted
  after insert on public.applications
  for each row execute function public.notify_on_application_submitted();

-- New: document uploaded
create or replace function public.notify_on_document_uploaded() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (user_id, title, body, type, application_id)
  values (
    new.student_id,
    'Document uploaded',
    new.file_name || ' was added to your application.',
    'document',
    new.application_id
  );
  return new;
end $$;

drop trigger if exists on_document_uploaded on public.documents;
create trigger on_document_uploaded
  after insert on public.documents
  for each row execute function public.notify_on_document_uploaded();
