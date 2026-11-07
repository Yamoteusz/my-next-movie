revoke all on table public.saved_movies from anon;
revoke all on table public.saved_movies from authenticated;
grant usage on schema public to authenticated;
grant select, insert, delete on table public.saved_movies to authenticated;
