-- Disposable CI PostgreSQL only; the runner rolls back this transaction.
do $$ begin
 if to_regprocedure('public.submit_external_measurement(jsonb)') is null then
  raise exception 'external measurement authenticated intake RPC is missing';
 end if;
end $$;
