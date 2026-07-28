-- =============================================================
-- Runnable schema for Supabase (Postgres)
-- Tables are ordered so every foreign-key target is created first.
-- Safe to run on a fresh Supabase project (auth.users already exists).
-- =============================================================

-- gen_random_uuid() is provided by the pgcrypto extension.
-- It is enabled by default on Supabase, but this makes the script self-contained.
create extension if not exists pgcrypto;

-- -------------------------------------------------------------
-- 1. profiles  (references auth.users — created by Supabase Auth)
-- -------------------------------------------------------------
create table if not exists public.profiles (
  id            uuid        not null,
  email         text        not null,
  full_name     text        not null default ''::text,
  role          text        not null default 'patient'::text,
  phone         text,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now(),
  wallet_address text,
  private_key   text,
  constraint profiles_pkey primary key (id),
  constraint profiles_id_fkey foreign key (id) references auth.users (id) on delete cascade
);

-- -------------------------------------------------------------
-- 2. patients  (references profiles)
-- -------------------------------------------------------------
create table if not exists public.patients (
  id                uuid        not null default gen_random_uuid(),
  profile_id        uuid        not null unique,
  date_of_birth     date,
  gender            text,
  blood_group       text,
  address           text,
  emergency_contact text,
  created_at        timestamptz default now(),
  updated_at        timestamptz default now(),
  constraint patients_pkey primary key (id),
  constraint patients_profile_id_fkey foreign key (profile_id) references public.profiles (id) on delete cascade
);

-- -------------------------------------------------------------
-- 3. doctors  (references profiles)
-- -------------------------------------------------------------
create table if not exists public.doctors (
  id                uuid        not null default gen_random_uuid(),
  profile_id        uuid        not null unique,
  specialization    text,
  license_number    text,
  hospital_name     text,
  experience_years  integer,
  created_at        timestamptz default now(),
  updated_at        timestamptz default now(),
  name              text,
  state             text,
  city              text,
  address           text,
  about             text,
  education         text,
  languages         text[]      default '{}'::text[],   -- was "ARRAY" in the export; not a runnable type
  consultation_fee  integer,
  available_online  boolean     default false,
  constraint doctors_pkey primary key (id),
  constraint doctors_profile_id_fkey foreign key (profile_id) references public.profiles (id) on delete cascade
);

-- -------------------------------------------------------------
-- 4. doctor_requests  (references profiles + doctors)
-- -------------------------------------------------------------
create table if not exists public.doctor_requests (
  id         uuid        not null default gen_random_uuid(),
  patient_id uuid        not null,
  doctor_id  uuid        not null,
  status     text        default 'pending'::text,
  created_at timestamptz default now(),
  constraint doctor_requests_pkey primary key (id),
  constraint fk_patient foreign key (patient_id) references public.profiles (id) on delete cascade,
  constraint fk_doctor  foreign key (doctor_id)  references public.doctors (id)  on delete cascade
);

-- -------------------------------------------------------------
-- 5. medical_records  (references profiles)
-- -------------------------------------------------------------
create table if not exists public.medical_records (
  id              uuid        not null default gen_random_uuid(),
  patient_id      uuid        not null,
  title           text        not null,
  category        text,
  filename        text,
  mime_type       text,
  file_size_bytes bigint,
  cid             text        not null,
  sha256          text        not null,
  encrypted_key   text        not null,
  iv              text        not null,
  created_at      timestamptz default now(),
  constraint medical_records_pkey primary key (id),
  constraint medical_records_patient_id_fkey foreign key (patient_id) references public.profiles (id) on delete cascade
);

-- -------------------------------------------------------------
-- 6. appointment_requests  (references profiles + doctors)
-- -------------------------------------------------------------
create table if not exists public.appointment_requests (
  id             uuid        not null default gen_random_uuid(),
  patient_id     uuid        not null,
  doctor_id      uuid        not null,
  preferred_date date        not null,
  preferred_time text        not null,
  notes          text,
  status         text        not null default 'pending'::text,
  created_at     timestamptz not null default now(),
  confirmed_date date,
  confirmed_time text,
  constraint appointment_requests_pkey primary key (id),
  constraint appt_fk_patient foreign key (patient_id) references public.profiles (id) on delete cascade,
  constraint appt_fk_doctor  foreign key (doctor_id)  references public.doctors (id)  on delete cascade
);

-- -------------------------------------------------------------
-- 7. shared_records  (references medical_records + doctors + profiles)
-- -------------------------------------------------------------
create table if not exists public.shared_records (
  id         uuid        not null default gen_random_uuid(),
  record_id  uuid        not null,
  patient_id uuid        not null,
  doctor_id  uuid        not null,
  shared_at  timestamptz not null default now(),
  expires_at timestamptz,
  constraint shared_records_pkey primary key (id),
  constraint shared_records_record_id_fkey  foreign key (record_id)  references public.medical_records (id) on delete cascade,
  constraint shared_records_doctor_id_fkey  foreign key (doctor_id)  references public.doctors (id)         on delete cascade,
  -- The original export had no FK on patient_id; added for consistency with the other tables.
  constraint shared_records_patient_id_fkey foreign key (patient_id) references public.profiles (id)        on delete cascade
);