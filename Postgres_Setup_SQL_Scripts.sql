-- create the database 
create database music_albums;

-- for the dev & admin users, a stored procedure will be created to handle their creation

-- admin users 
CREATE OR REPLACE PROCEDURE admin_user_creation(IN un name, INOUT pwd text)
 LANGUAGE plpgsql
AS $procedure$
DECLARE 
BEGIN
	
	IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = un) THEN
		select 'privilege(s) updated'	into pwd;
	ELSE 
		select array_to_string(array(select 
		substr('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789~!@#$%^&*()_+{}|:<>?-=[]\;,./',
		((random()*(92-1)+1)::integer),1) 
		from generate_series(1,15)),'') 
		into pwd;
	END IF;

	IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = un) THEN
		 RAISE NOTICE 'Role already exists. Skipping.';
    ELSE
	  EXECUTE format('CREATE ROLE "'||un||'" SUPERUSER CREATEDB CREATEROLE INHERIT LOGIN REPLICATION BYPASSRLS password '''||pwd||''';');
    END IF;

   
END;
$procedure$
;


-- dev users
CREATE OR REPLACE PROCEDURE dev_user_creation(IN un name, INOUT pwd text, IN priv text)
 LANGUAGE plpgsql
AS $procedure$
DECLARE 
BEGIN
	
	IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = un) THEN
		select 'privilege(s) updated'	into pwd;
	ELSE 
		select array_to_string(array(select 
		substr('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789~!@#$%^&*()_+{}|:<>?-=[]\;,./',
		((random()*(92-1)+1)::integer),1) 
		from generate_series(1,15)),'') 
		into pwd;
	END IF;

	IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = un) THEN
		 RAISE NOTICE 'Role already exists. Skipping.';
    ELSE
	  EXECUTE format('CREATE ROLE "'||un||'" LOGIN PASSWORD '''||pwd||''';');
    END IF;

    EXECUTE format('GRANT '||priv||' ON ALL TABLES IN SCHEMA public TO "'||un||'";');

    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT '||priv||' ON TABLES TO "'||un||'";');
 
    EXECUTE format('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO "'||un||'";');

	EXECUTE format('GRANT USAGE ON SCHEMA public TO "'||un||'";');
   
END;
$procedure$
;

-- create the 10 dev users & 5 admin users, 
-- Note, the admin stored procedure takes 2 parameters, the pwd is a constant; it auto-generates a strong password. only the first parameter should be changed
-- Note, the dev stored procedure takes 3 parameters, the pwd is a constant; it auto-generates a strong password. only the first & third parameter should be changed
-- # for the admins
call admin_user_creation('admin1','pwd');
call admin_user_creation('admin2','pwd');
call admin_user_creation('admin3','pwd');
call admin_user_creation('admin4','pwd');
call admin_user_creation('admin5','pwd');

-- #for the devs
call dev_user_creation('dev1','pwd','select');
call dev_user_creation('dev2','pwd','select');
call dev_user_creation('dev3','pwd','select');
call dev_user_creation('dev4','pwd','select');
call dev_user_creation('dev5','pwd','select');
call dev_user_creation('dev6','pwd','select');
call dev_user_creation('dev7','pwd','select');
call dev_user_creation('dev8','pwd','select');
call dev_user_creation('dev9','pwd','select');
call dev_user_creation('dev10','pwd','select');

-- confirm users have been created & read privileges granted
SELECT grantor, grantee, table_catalog database_, table_schema, table_name, 
string_agg(privilege_type, ', ') privilege_type
FROM information_schema.role_table_grants 
WHERE 1=1
and grantee = 'dev1'
group by 1,2,3,4,5
order by 5, string_agg(privilege_type, ', ') 
;

-- create the sequence that will be used in generating ids
create sequence hibernate_sequence
start with 1 increment by 1
no minvalue no maxvalue no cycle
;

-- create the tables & relationships

-- for the management of users & assignging of privileges. The users, roles, user_roles, permissions & role_permissions tables will be created with needed relationships
CREATE TABLE public.users (
	id bigint DEFAULT nextval('hibernate_sequence'::regclass) NOT NULL,
	username varchar(255) NOT NULL,
	email varchar(255) NOT NULL,
	pwd varchar(255) NOT NULL,
	created_on timestamp DEFAULT current_timestamp NULL,
	last_login timestamp DEFAULT current_timestamp NULL,
	CONSTRAINT users_id PRIMARY KEY (id),
	CONSTRAINT users_unique_username UNIQUE (username),
	CONSTRAINT users_unique_email UNIQUE (email)
);

CREATE TABLE public.roles (
	id bigint DEFAULT nextval('hibernate_sequence'::regclass) NOT NULL,
	rolename varchar(255) NOT NULL,
	created_on timestamp DEFAULT current_timestamp null,
	CONSTRAINT roles_id PRIMARY KEY (id),
	CONSTRAINT roles_rolename UNIQUE (rolename)
);

CREATE TABLE public.user_roles (
	id bigint DEFAULT nextval('hibernate_sequence'::regclass) NOT NULL,
	user_id bigint NOT NULL,
	role_id bigint NOT NULL,
	CONSTRAINT user_roles_pk PRIMARY KEY (id),
	CONSTRAINT user_roles_unique UNIQUE (user_id, role_id),
	CONSTRAINT user_roles_roles_fk FOREIGN KEY (role_id) REFERENCES public.roles(id),
	CONSTRAINT user_roles_users_fk FOREIGN KEY (user_id) REFERENCES public.users(id)
);

CREATE TABLE public.permissions (
	id bigint DEFAULT nextval('hibernate_sequence'::regclass) NOT NULL,
	permission_name varchar(255) NOT NULL,
    created_on timestamp DEFAULT current_timestamp null,
	CONSTRAINT permissions_pk PRIMARY KEY (id),
	CONSTRAINT permissions_unique UNIQUE (permission_name)
);

CREATE TABLE public.role_permissions (
	id bigint DEFAULT nextval('hibernate_sequence'::regclass) NOT NULL,
	role_id bigint NOT NULL,
	permission_id bigint NOT NULL,
	CONSTRAINT role_permissions_pk PRIMARY KEY (id),
	CONSTRAINT role_permissions_unique UNIQUE (role_id,permission_id),
	CONSTRAINT role_permissions_roles_fk FOREIGN KEY (role_id) REFERENCES public.roles(id),
	CONSTRAINT role_permissions_permissions_fk FOREIGN KEY (permission_id) REFERENCES public.permissions(id)
);

-- the tables to be created below will contain details about the artist, the various achievements, albums, tracks, compilations, tracks_complitions etc & establish the required relationships
CREATE TABLE public.artists (
	id bigint DEFAULT nextval('hibernate_sequence'::regclass) NOT NULL,
	full_name varchar(255) NOT NULL,
	country_of_origin varchar(255) NULL,
	introduction_year bigint NULL,
	CONSTRAINT artists_pk PRIMARY KEY (id)
);

CREATE TABLE public.albums (
	id bigint DEFAULT nextval('hibernate_sequence'::regclass) NOT NULL,
	title varchar(255) NOT NULL,
	date_of_release date NULL,
	price float8 NOT NULL,
	quantity_in_stock bigint DEFAULT 0 NOT NULL,
	description varchar(255) NULL,
	CONSTRAINT albums_pk PRIMARY KEY (id)
);

CREATE TABLE public.artists_albums (
	id bigint DEFAULT nextval('hibernate_sequence'::regclass) NOT NULL,
	album_id bigint NOT NULL,
	artist_id bigint NOT NULL,
	CONSTRAINT artists_albums_pk PRIMARY KEY (id),
	CONSTRAINT artists_albums_unique UNIQUE (album_id, artist_id),
	CONSTRAINT artists_albums_albums_fk FOREIGN KEY (album_id) REFERENCES public.albums(id),
	CONSTRAINT artists_albums_artists_fk FOREIGN KEY (artist_id) REFERENCES public.artists(id)
);

CREATE TABLE public.tracks (
	id bigint DEFAULT nextval('hibernate_sequence'::regclass) NOT NULL,
	album_id bigint NOT NULL,
	title varchar(255) NOT NULL,
	song_duration_in_secs bigint NULL,
	file_location varchar(255) DEFAULT 'path/to/file'::character varying NULL,
	CONSTRAINT tracks_pk PRIMARY KEY (id),
	CONSTRAINT tracks_albums_fk FOREIGN KEY (album_id) REFERENCES public.albums(id)
);

CREATE TABLE public.achievements (
	id bigint DEFAULT nextval('hibernate_sequence'::regclass) NOT NULL,
	type_of_achievements varchar(255) NULL,
	descriptions varchar(1024) NULL,
	achievement_year bigint NULL,
	artist_id bigint NOT NULL,
	CONSTRAINT achievements_pk PRIMARY KEY (id),
	CONSTRAINT achievements_artists_fk FOREIGN KEY (artist_id) REFERENCES public.artists(id)
);

-- the tables to be created below will contain details about sales, orders from store, payment and history etc & establish the required relationships
-- create an enum data type for the status_of_orders for the orders table 
CREATE TYPE status_of_order_dt AS ENUM ('PENDING', 'PROCESSING', 'APPROVED', 'FAILED');

CREATE TABLE public.orders (
	id bigint DEFAULT nextval('hibernate_sequence'::regclass) NOT NULL,
	user_id bigint NOT NULL,
	date_of_order timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
	amount float8 DEFAULT 0 NOT NULL,
	delivery_address varchar(2048) NULL,
	status_of_order public.status_of_order_dt DEFAULT 'PENDING'::status_of_order_dt NULL,
	CONSTRAINT orders_pk PRIMARY KEY (id)
);

CREATE TABLE public.order_items (
	id bigint DEFAULT nextval('hibernate_sequence'::regclass) NOT NULL,
	order_id bigint NOT NULL,
	album_id bigint NOT NULL,
	quantity bigint NOT NULL,
	unit_price float8 NOT NULL,
	total_value float8 GENERATED ALWAYS AS (quantity::double precision * unit_price) STORED NOT NULL,
	CONSTRAINT order_items_pk PRIMARY KEY (id),
	CONSTRAINT order_items_albums_fk FOREIGN KEY (album_id) REFERENCES public.albums(id),
	CONSTRAINT order_items_orders_fk FOREIGN KEY (order_id) REFERENCES public.orders(id)
);

-- create an enum data type for the payment_order_status 
CREATE TYPE payment_order_status_dt AS ENUM ('SUCCESS', 'FAILED', 'REFUNDED');

CREATE TABLE public.payments (
	id bigint DEFAULT nextval('hibernate_sequence'::regclass) NOT NULL,
	order_id bigint NOT NULL,
	payment_date timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
	amount float8 NOT NULL,
	payment_order_status public.payment_order_status_dt NULL,
	CONSTRAINT payments_pk PRIMARY KEY (id),
	CONSTRAINT payments_orders_fk FOREIGN KEY (order_id) REFERENCES public.orders(id)
);

-- confirm the enum data type content created
select t.typname AS dt, e.enumlabel AS value, e.enumsortorder AS order_
FROM pg_enum e, pg_type t 
where t.oid = e.enumtypid
and t.typcategory = 'E'
order by e.enumtypid, 1,3
;

-- creating indexes on some of the tables.
-- NB: Too many indexes slow down writes; too few indexes kill read performance. Striking the right balance is key. ⁠
CREATE INDEX albums_title_idx ON public.albums (title);
CREATE INDEX artists_full_name_idx ON public.artists (full_name);
CREATE INDEX orders_date_of_order_idx ON public.orders (date_of_order);
CREATE INDEX payments_payment_order_status_idx ON public.payments (payment_order_status);
CREATE INDEX tracks_title_idx ON public.tracks (title);

-- inserting records into the tables 
INSERT INTO public.roles
( rolename, created_on)
values
( 'ADMIN',NOW()),
( 'STAFF',NOW()),
( 'CUSTOMER',NOW())
;

INSERT INTO public.permissions
( permission_name, created_on)
values
( 'MANAGE USERS',NOW()),
( 'SALES PROCESSING',NOW()),
( 'CATALOGS CATEGORIZATION',NOW())
;

insert into public.users 
values 
( 'ADMIN ADMIN', 'admin_admin@email.com', crypt('123pwd#', gen_salt('bf')), now(), now()),
( 'Sales Mgr', 'sales_mgr@email.com', crypt('*321pwd#', gen_salt('bf')), now(), now())
( 'James Gunn', 'james_gunn@email.com', crypt('*myPwd#', gen_salt('bf')))
;

INSERT INTO public.user_roles (user_id,role_id)
VALUES (9,3);

INSERT INTO public.role_permissions (role_id,permission_id)
VALUES (3,6);

INSERT INTO public.artists
(full_name, country_of_origin, introduction_year)
VALUES
('Johnny Drille', 'Nigeria', 2013),
('Chike', 'Nigeria', 2016);

INSERT INTO public.achievements
( type_of_achievements, descriptions, achievement_year, artist_id)
VALUES
('Milestone', 'Debut Single', 2015, 14),
('Award', 'Headies', 2020, 20),
('Milestone', 'Debut Album', 2020, 20);

INSERT INTO public.albums (title,date_of_release,price,quantity_in_stock)
VALUES ('Boo of the Booless','2020-10-20',1750.0,1000000);

INSERT INTO public.artists_albums
(album_id, artist_id)
VALUES(28, 20);

INSERT INTO public.orders (user_id,amount,status_of_order)
VALUES (30,50000.0,'APPROVED'::public.status_of_order_dt)
;

INSERT INTO public.order_items (order_id,album_id,quantity,unit_price)
VALUES (31,28,10,5000.0)
;

INSERT INTO public.payments
(order_id, amount, payment_order_status)
VALUES(31, 50000.0, 'SUCCESS'::public.payment_order_status_dt);


-- confirm sales on the customer 
select oi.id,u.username, oi.total_value, o.status_of_order, p.payment_order_status
from albums a 
join order_items oi on a.id = oi.album_id 
join orders o on o.id = oi.order_id
join users u on u.id = o.user_id
join payments p on p.order_id = o.id
where u.id = 30
;