create table if not exists public.approval_reviews (
  id uuid primary key default gen_random_uuid(),
  internship_id uuid not null references public.internships(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  review_stage text not null check (review_stage in ('faculty', 'tp_admin')),
  status text not null check (
    status in ('pending', 'under_review', 'approved', 'rejected')
  ),
  remarks text,
  created_at timestamptz not null default now()
);

create index if not exists approval_reviews_internship_created_at_idx
  on public.approval_reviews (internship_id, created_at desc);

alter table public.approval_reviews enable row level security;

drop policy if exists "Approval staff read reviews"
  on public.approval_reviews;
create policy "Approval staff read reviews"
  on public.approval_reviews for select to authenticated
  using (public.current_role_of_user() in ('faculty', 'tnp'));

drop policy if exists "Reviewers create their own stage reviews"
  on public.approval_reviews;
create policy "Reviewers create their own stage reviews"
  on public.approval_reviews for insert to authenticated
  with check (
    reviewer_id = auth.uid()
    and (
      (review_stage = 'faculty'
        and public.current_role_of_user() = 'faculty')
      or
      (review_stage = 'tp_admin'
        and public.current_role_of_user() = 'tnp'
        and exists (
          select 1 from public.internships i
          where i.id = internship_id and i.status = 'approved'
        ))
    )
  );

drop policy if exists "Reviewers update their own reviews"
  on public.approval_reviews;
create policy "Reviewers update their own reviews"
  on public.approval_reviews for update to authenticated
  using (reviewer_id = auth.uid())
  with check (reviewer_id = auth.uid());
