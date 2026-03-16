create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null default '',
  name text not null default '',
  avatar text,
  phone text not null default '',
  location text not null default '',
  occupation text not null default '',
  bio text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  description text,
  priority text not null default 'medium',
  status text not null default 'pending',
  due_date timestamptz not null default now(),
  notes text,
  recurring boolean not null default false,
  tags jsonb not null default '[]'::jsonb,
  subtasks jsonb not null default '[]'::jsonb,
  category text not null default 'personal',
  reminder boolean not null default false,
  repeat text not null default 'None',
  completed_subtasks integer not null default 0,
  due_time text,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.assistant_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  preview jsonb,
  confirmed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.task_attachments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  storage_path text not null unique,
  file_name text not null,
  mime_type text not null default '',
  size_bytes bigint not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists tasks_user_id_due_date_idx
  on public.tasks (user_id, due_date);

create index if not exists assistant_messages_user_id_created_at_idx
  on public.assistant_messages (user_id, created_at);

create index if not exists task_attachments_user_id_task_id_created_at_idx
  on public.task_attachments (user_id, task_id, created_at);

alter table public.users enable row level security;
alter table public.tasks enable row level security;
alter table public.assistant_messages enable row level security;
alter table public.task_attachments enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'users'
      and policyname = 'Users can manage own profile'
  ) then
    create policy "Users can manage own profile"
      on public.users
      for all
      using (auth.uid() = id)
      with check (auth.uid() = id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'tasks'
      and policyname = 'Users can manage own tasks'
  ) then
    create policy "Users can manage own tasks"
      on public.tasks
      for all
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'assistant_messages'
      and policyname = 'Users can manage own assistant messages'
  ) then
    create policy "Users can manage own assistant messages"
      on public.assistant_messages
      for all
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'task_attachments'
      and policyname = 'Users can manage own task attachments'
  ) then
    create policy "Users can manage own task attachments"
      on public.task_attachments
      for all
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end
$$;

insert into storage.buckets (id, name, public)
values ('task-attachments', 'task-attachments', false)
on conflict (id) do nothing;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users can upload own task attachments'
  ) then
    create policy "Users can upload own task attachments"
      on storage.objects
      for insert
      to authenticated
      with check (
        bucket_id = 'task-attachments'
        and auth.uid()::text = (storage.foldername(name))[1]
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users can read own task attachments'
  ) then
    create policy "Users can read own task attachments"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id = 'task-attachments'
        and auth.uid()::text = (storage.foldername(name))[1]
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users can delete own task attachments'
  ) then
    create policy "Users can delete own task attachments"
      on storage.objects
      for delete
      to authenticated
      using (
        bucket_id = 'task-attachments'
        and auth.uid()::text = (storage.foldername(name))[1]
      );
  end if;
end
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (
    id,
    email,
    name,
    avatar,
    phone,
    location,
    occupation,
    bio,
    created_at,
    updated_at
  )
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'name', split_part(coalesce(new.email, ''), '@', 1)),
    null,
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce(new.raw_user_meta_data ->> 'location', ''),
    coalesce(new.raw_user_meta_data ->> 'occupation', ''),
    coalesce(new.raw_user_meta_data ->> 'bio', ''),
    coalesce(new.created_at, now()),
    now()
  )
  on conflict (id) do update
  set
    email = excluded.email,
    name = coalesce(excluded.name, public.users.name),
    phone = coalesce(excluded.phone, public.users.phone),
    location = coalesce(excluded.location, public.users.location),
    occupation = coalesce(excluded.occupation, public.users.occupation),
    bio = coalesce(excluded.bio, public.users.bio),
    updated_at = now();

  return new;
end;
$$;

insert into public.users (
  id,
  email,
  name,
  avatar,
  phone,
  location,
  occupation,
  bio,
  created_at,
  updated_at
)
select
  au.id,
  coalesce(au.email, ''),
  coalesce(au.raw_user_meta_data ->> 'name', split_part(coalesce(au.email, ''), '@', 1)),
  null,
  coalesce(au.raw_user_meta_data ->> 'phone', ''),
  coalesce(au.raw_user_meta_data ->> 'location', ''),
  coalesce(au.raw_user_meta_data ->> 'occupation', ''),
  coalesce(au.raw_user_meta_data ->> 'bio', ''),
  coalesce(au.created_at, now()),
  now()
from auth.users au
on conflict (id) do nothing;

drop trigger if exists set_users_updated_at on public.users;
create trigger set_users_updated_at
before update on public.users
for each row
execute function public.set_updated_at();

drop trigger if exists set_tasks_updated_at on public.tasks;
create trigger set_tasks_updated_at
before update on public.tasks
for each row
execute function public.set_updated_at();

drop trigger if exists set_assistant_messages_updated_at on public.assistant_messages;
create trigger set_assistant_messages_updated_at
before update on public.assistant_messages
for each row
execute function public.set_updated_at();

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

create or replace function public.delete_current_user()
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.assistant_messages where user_id = current_user_id;
  delete from public.task_attachments where user_id = current_user_id;
  delete from public.tasks where user_id = current_user_id;
  delete from public.users where id = current_user_id;
  delete from auth.users where id = current_user_id;

  return true;
end;
$$;

grant execute on function public.delete_current_user() to authenticated;
