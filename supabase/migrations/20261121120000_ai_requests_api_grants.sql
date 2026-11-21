revoke all on table public.ai_requests from anon;
revoke all on table public.ai_requests from authenticated;
grant usage on schema public to authenticated;
grant select, insert on table public.ai_requests to authenticated;
grant usage on sequence public.ai_requests_id_seq to authenticated;
