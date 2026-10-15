-- ============================================================
-- Geo-tagged progress for the public.internships schema in schema.sql.
-- Apply schema.sql before this migration.
-- ============================================================

-- 1. Site location on each internship -------------------------
alter table public.internships
  add column if not exists site_lat          double precision,
  add column if not exists site_lng          double precision,
  add column if not exists geofence_radius_m integer not null default 500
    check (geofence_radius_m > 0);

-- 2. Distance helper (Haversine, metres) ----------------------
create or replace function public.haversine_m(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
) returns double precision
language sql immutable as $$
  select 2 * 6371000 * asin(sqrt(
    least(1.0,
      power(sin(radians(lat2 - lat1) / 2), 2) +
      cos(radians(lat1)) * cos(radians(lat2)) *
      power(sin(radians(lng2 - lng1) / 2), 2)
    )
  ));
$$;

-- 3. Geo-tagged progress log ----------------------------------
create table if not exists public.geo_progress_logs (
  id                    uuid primary key default gen_random_uuid(),
  client_ref            uuid unique not null default gen_random_uuid(), -- idempotency key (used by Hive sync in S4)
  internship_id         uuid not null references public.internships(id) on delete cascade,
  student_id            uuid not null default auth.uid() references auth.users(id),
  progress_percent      integer not null check (progress_percent between 0 and 100),
  task_summary          text not null check (char_length(task_summary) between 3 and 500),
  latitude              double precision not null check (latitude  between -90  and 90),
  longitude             double precision not null check (longitude between -180 and 180),
  accuracy_m            double precision,
  captured_at           timestamptz not null default now(),
  distance_from_site_m  double precision,
  within_geofence       boolean,
  created_at            timestamptz not null default now()
);

create index if not exists idx_geo_logs_app_time
  on public.geo_progress_logs (internship_id, captured_at desc);

-- 4. Validate + compute geofence before insert ----------------
create or replace function public.geo_logs_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_internship record;
begin
  select student_id, site_lat, site_lng, geofence_radius_m
    into v_internship
    from public.internships
   where id = new.internship_id;

  if not found then
    raise exception 'Internship not found';
  end if;
  if v_internship.student_id <> new.student_id then
    raise exception 'You can only log progress for your own internship';
  end if;
  if new.captured_at > now() + interval '5 minutes' then
    raise exception 'captured_at cannot be in the future';
  end if;

  new.distance_from_site_m := null;
  new.within_geofence := null;
  if v_internship.site_lat is not null and v_internship.site_lng is not null then
    new.distance_from_site_m :=
      public.haversine_m(
        new.latitude, new.longitude,
        v_internship.site_lat, v_internship.site_lng
      );
    new.within_geofence :=
      new.distance_from_site_m <= v_internship.geofence_radius_m;
  end if;
  return new;
end $$;

drop trigger if exists trg_geo_logs_before_insert on public.geo_progress_logs;
create trigger trg_geo_logs_before_insert
  before insert on public.geo_progress_logs
  for each row execute function public.geo_logs_before_insert();

-- 5. Roll progress up to the internship after insert ----------
create or replace function public.geo_logs_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.internships
     set progress = greatest(progress, new.progress_percent)
   where id = new.internship_id;
  return new;
end $$;

drop trigger if exists trg_geo_logs_after_insert on public.geo_progress_logs;
create trigger trg_geo_logs_after_insert
  after insert on public.geo_progress_logs
  for each row execute function public.geo_logs_after_insert();

-- 6. Latest log per internship (dashboards) -------------------
create or replace view public.geo_progress_latest
with (security_invoker = true) as
select distinct on (internship_id) *
  from public.geo_progress_logs
 order by internship_id, captured_at desc;

-- 7. Row Level Security ---------------------------------------
alter table public.geo_progress_logs enable row level security;

drop policy if exists "student inserts own logs" on public.geo_progress_logs;
create policy "student inserts own logs" on public.geo_progress_logs
  for insert to authenticated
  with check (
    student_id = auth.uid()
    and exists (
      select 1
        from public.internships i
       where i.id = geo_progress_logs.internship_id
         and i.student_id = auth.uid()
    )
  );

drop policy if exists "student reads own logs" on public.geo_progress_logs;
create policy "student reads own logs" on public.geo_progress_logs
  for select to authenticated
  using (student_id = auth.uid());

drop policy if exists "staff reads all logs" on public.geo_progress_logs;
create policy "staff reads all logs" on public.geo_progress_logs
  for select to authenticated
  using (exists (
    select 1 from public.profiles p
     where p.id = auth.uid()
       and p.role in ('faculty', 'tnp', 'industry')
  ));
