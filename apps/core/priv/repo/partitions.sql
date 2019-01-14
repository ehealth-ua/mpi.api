create table person_addresses_kyiv(CHECK ()settlement_id = 'adaa4abf-f530-461c-bcbf-a0ac210d955b') INHERITS (person_addresses);
create table person_addresses_kharkiv(CHECK (settlement_id = '1241d1f9-ae81-4fe5-b614-f4f780a5acf0')) INHERITS (person_addresses);
create table person_addresses_odesa(CHECK (settlement_id = 'c9fe33e1-88f6-4bf3-88a6-3fe33432470a')) INHERITS (person_addresses);
create table person_addresses_zaporizhzhia(CHECK (settlement_id = 'd8c86f69-68c5-4f11-b8a1-a57fc60454f0')) INHERITS (person_addresses);
create table person_addresses_vynnytsia(CHECK (settlement_id = '90cf1df9-7306-424d-98b0-18f03098f9bd')) INHERITS (person_addresses);
create table person_addresses_mariupol(CHECK (settlement_id = '0936210c-16d0-4e30-8fb5-7dbedbb171b7')) INHERITS (person_addresses);
create table person_addresses_mykolaiv(CHECK (settlement_id = '1da99ee1-ffa1-4417-b0ce-5d67b9cf42bf')) INHERITS (person_addresses);
create table person_addresses_zhytomyr(CHECK (settlement_id = '258a479a-3934-4f10-b997-b9d42a3b2267')) INHERITS (person_addresses);
create table person_addresses_khmelnytskyi(CHECK (settlement_id = 'cf312385-7788-4dde-ba22-f549462c17a0')) INHERITS (person_addresses);
create table person_addresses_poltava(CHECK (settlement_id = 'e3fc90c9-1704-48a8-97a3-40f8bca461d8')) INHERITS (person_addresses);
create table person_addresses_chernigiv(CHECK (settlement_id = '01022759-b478-4952-97f2-cbada0045fee')) INHERITS (person_addresses);
create table person_addresses_kherson(CHECK (settlement_id = '474ea27b-c826-4fc0-acfa-7aab2b7973d4')) INHERITS (person_addresses);
create table person_addresses_cherkasy(CHECK (settlement_id = '36742336-aac1-4f5d-a0df-7468a00e371a')) INHERITS (person_addresses);
create table person_addresses_chernivtsi(CHECK (settlement_id = '401063bd-4871-4a23-8e6b-998e0eec4b76')) INHERITS (person_addresses);
create table person_addresses_ivano_frankivsk(CHECK (settlement_id = 'ecf8bf1d-55a3-4a10-ac8c-186ce6c4eddb')) INHERITS (person_addresses);
create table person_addresses_rivne(CHECK (settlement_id = '7566d098-3526-4768-97da-2de9e7c5e3a3')) INHERITS (person_addresses);
create table person_addresses_ternopil(CHECK (settlement_id = 'fe9f62ee-7996-4e03-b7d4-132b4cc4ed7d')) INHERITS (person_addresses);
create table person_addresses_kamianske(CHECK (settlement_id = '748f3e3e-46a6-440f-bac9-9124f988e74c')) INHERITS (person_addresses);

CREATE OR REPLACE FUNCTION person_addresses_function() RETURNS TRIGGER AS $$
BEGIN
if NEW.settlement_id = 'adaa4abf-f530-461c-bcbf-a0ac210d955b' then
 insert into person_addresses_kyiv values (NEW.*);

elseif NEW.settlement_id = '1241d1f9-ae81-4fe5-b614-f4f780a5acf0' then
 insert into person_addresses_kharkiv values (NEW.*);

elseif NEW.settlement_id = 'c9fe33e1-88f6-4bf3-88a6-3fe33432470a' then
 insert into person_addresses_odesa values (NEW.*);

elseif NEW.settlement_id = 'd8c86f69-68c5-4f11-b8a1-a57fc60454f0' then
 insert into person_addresses_zaporizhzhia values (NEW.*);

elseif NEW.settlement_id = '90cf1df9-7306-424d-98b0-18f03098f9bd' then
 insert into person_addresses_vynnytsia values (NEW.*);

elseif NEW.settlement_id = '0936210c-16d0-4e30-8fb5-7dbedbb171b7' then
 insert into person_addresses_mariupol values (NEW.*);

elseif NEW.settlement_id = '1da99ee1-ffa1-4417-b0ce-5d67b9cf42bf' then
 insert into person_addresses_mykolaiv values (NEW.*);

elseif NEW.settlement_id = '258a479a-3934-4f10-b997-b9d42a3b2267' then
 insert into person_addresses_zhytomyr values (NEW.*);

elseif NEW.settlement_id = '26b390f1-0a31-47fa-8c1b-328b833729fc' then
 insert into person_addresses_lviv values (NEW.*);

elseif NEW.settlement_id = 'ee73597c-273d-457c-a01a-5c86f2904db4' then
 insert into person_addresses_dnipro values (NEW.*);

elseif NEW.settlement_id = 'c0094697-555a-4ac3-8914-d3f97e07e53b' then
 insert into person_addresses_krivyi_rih values (NEW.*);

elseif NEW.settlement_id = 'cf312385-7788-4dde-ba22-f549462c17a0' then
 insert into person_addresses_khmelnytskyi values (NEW.*);

elseif NEW.settlement_id = 'e3fc90c9-1704-48a8-97a3-40f8bca461d8' then
 insert into person_addresses_poltava values (NEW.*);

elseif NEW.settlement_id = '01022759-b478-4952-97f2-cbada0045fee' then
 insert into person_addresses_chernigiv values (NEW.*);

elseif NEW.settlement_id = '474ea27b-c826-4fc0-acfa-7aab2b7973d4' then
 insert into person_addresses_kherson values (NEW.*);

elseif NEW.settlement_id = '36742336-aac1-4f5d-a0df-7468a00e371a' then
 insert into person_addresses_cherkasy values (NEW.*);

elseif NEW.settlement_id = '401063bd-4871-4a23-8e6b-998e0eec4b76' then
 insert into person_addresses_chernivtsi values (NEW.*);

elseif NEW.settlement_id = 'ecf8bf1d-55a3-4a10-ac8c-186ce6c4eddb' then
 insert into person_addresses_ivano_frankivsk values (NEW.*);

elseif NEW.settlement_id = '7566d098-3526-4768-97da-2de9e7c5e3a3' then
 insert into person_addresses_rivne values (NEW.*);

elseif NEW.settlement_id = 'fe9f62ee-7996-4e03-b7d4-132b4cc4ed7d' then
 insert into person_addresses_ternopil values (NEW.*);

elseif NEW.settlement_id = '748f3e3e-46a6-440f-bac9-9124f988e74c' then
 insert into person_addresses_kamianske values (NEW.*);

else insert into person_addresses  values (NEW.*);
end if;
RETURN NULL;
END;
$$ LANGUAGE PLPGSQL;

CREATE TRIGGER insert_person_addresses before insert on person_addresses
 for each row execute PROCEDURE person_addresses_function();

 --TODO: BUILD INDEXES FOR ALL CHILDREN TABLES#

/*ADDITIONAL INDEXES*/

/*script generates queries*/
 select 'create index concurrently on person_addresses_kyiv(person_id) where person_first_name = ''' || person_first_name || '''' from
   (select person_first_name, count(*) from person_addresses_kyiv group by person_first_name order by 2 desc limit 40)s;

/*children tables*/
SELECT c.relname AS child FROM pg_inherits JOIN pg_class AS c ON (inhrelid=c.oid) JOIN pg_class as p
  ON (inhparent=p.oid) and p.relname = 'person_addresses';

/*dynamic sql*/
create or replace function from_table_name(p_table in text)
                           returns setof text language plpgsql immutable as $$
begin
  return query execute 'select person_first_name
    from (select person_first_name, count(*) from '|| p_table || ' group by person_first_name order by 2 desc limit 40)s';
end;$$;

/*final function*/
create or replace function generate_index_query(p_table in text) returns setof text language plpgsql as $$
declare
r text;
sql text;
set_id text;
begin
for r in select from_table_name(p_table) loop
EXECUTE 'select settlement_id from '||p_table||' limit 1;' into set_id;
sql = 'create index concurrently  '||p_table||'_'||r||'_indx on '||p_table||'(person_id, inserted_at) where person_first_name = '''||r||''' and
settlement_id = '''||set_id||''';';
return next sql;
end loop;
return;
end; $$;

/*call text generates indexes for children tables*/
SELECT generate_index_query(c.relname) AS child FROM pg_inherits JOIN pg_class AS c
ON (inhrelid=c.oid) JOIN pg_class as p ON (inhparent=p.oid) and p.relname = 'person_addresses';

/*call text generates indexes for main table*/
