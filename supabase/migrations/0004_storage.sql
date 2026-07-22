-- PAWD — Storage: pet photos + chat images
-- Path convention: pet-photos/{owner_id}/{pet_id}/{uuid}.jpg
--                  chat-images/{owner_id}/{uuid}.jpg
insert into storage.buckets (id, name, public)
values ('pet-photos', 'pet-photos', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('chat-images', 'chat-images', true)
on conflict (id) do nothing;

-- Public read (images are served via CDN; approval gate is at the DB row level).
drop policy if exists "pet photos public read" on storage.objects;
create policy "pet photos public read" on storage.objects
  for select using (bucket_id in ('pet-photos', 'chat-images'));

-- Authenticated users may write only under their own owner-id prefix.
drop policy if exists "pet photos owner write" on storage.objects;
create policy "pet photos owner write" on storage.objects
  for insert to authenticated with check (
    bucket_id in ('pet-photos', 'chat-images')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "pet photos owner update" on storage.objects;
create policy "pet photos owner update" on storage.objects
  for update to authenticated using (
    bucket_id in ('pet-photos', 'chat-images')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "pet photos owner delete" on storage.objects;
create policy "pet photos owner delete" on storage.objects
  for delete to authenticated using (
    bucket_id in ('pet-photos', 'chat-images')
    and (storage.foldername(name))[1] = auth.uid()::text
  );
