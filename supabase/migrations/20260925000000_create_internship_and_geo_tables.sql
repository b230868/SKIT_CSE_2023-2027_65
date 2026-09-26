-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. Internships Table (Sprint 2)
create table public.internships (
  id uuid default uuid_generate_v4() primary key,
  student_id uuid references auth.users(id) on delete cascade,
  company_name text not null,
  role text not null,
  start_date date not null,
  end_date date not null,
  status text default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 2. Internship Documents Table (Sprint 2 - Document APIs)
create table public.internship_documents (
  id uuid default uuid_generate_v4() primary key,
  internship_id uuid references public.internships(id) on delete cascade,
  document_type text not null check (document_type in ('offer_letter', 'completion_certificate', 'progress_report')),
  file_url text not null,
  uploaded_at timestamp with time zone default timezone('utc'::text, now())
);

-- 3. Geo-Tagged Check-ins Table (Sprint 3 - GPS Tracking)
create table public.geo_checkins (
  id uuid default uuid_generate_v4() primary key,
  student_id uuid references auth.users(id) on delete cascade,
  internship_id uuid references public.internships(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  location_accuracy double precision, -- in meters
  check_in_time timestamp with time zone default timezone('utc'::text, now())
);

-- Enable Row Level Security (RLS)
alter table public.internships enable row level security;
alter table public.internship_documents enable row level security;
alter table public.geo_checkins enable row level security;

-- Basic RLS Policies (Allow users to read/write their own data)
create policy "Students can view own internships" on public.internships for select using (auth.uid() = student_id);
create policy "Students can insert own internships" on public.internships for insert with check (auth.uid() = student_id);

create policy "Students can view own documents" on public.internship_documents for select using (
  internship_id in (select id from public.internships where student_id = auth.uid())
);
create policy "Students can upload documents" on public.internship_documents for insert with check (
  internship_id in (select id from public.internships where student_id = auth.uid())
);

create policy "Students can view own geo checkins" on public.geo_checkins for select using (auth.uid() = student_id);
create policy "Students can insert own geo checkins" on public.geo_checkins for insert with check (auth.uid() = student_id);