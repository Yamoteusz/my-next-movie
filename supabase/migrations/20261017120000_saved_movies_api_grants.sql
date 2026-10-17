-- Projects with automatic Data API grants disabled need explicit privileges.
-- RLS from the preceding migration still restricts each operation to auth.uid().
revoke all on table public.saved_movies from anon;
revoke all on table public.saved_movies from authenticated;
grant usage on schema public to authenticated;
grant select, insert, delete on table public.saved_movies to authenticated;
