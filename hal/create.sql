/*
 createuser -s -d -U postgres -P hal
 createdb -U hal hal
 psql -U hal < create.sql

 ... or pg_restore -d hal -U hal -c latest.pg 
*/

create table memberType (
       id integer primary key, 	
       created timestamp default now(),

       memberType varchar(50),
       monthlyFee numeric(10,2),

       doorAccess boolean,
);

insert into memberType (id, memberType, monthlyFee, doorAccess) 
       values (1, "Betalende medlem", 150, 1);
insert into memberType (id, memberType, monthlyFee, doorAccess) 
       values (2, "Gratis-medlem", 0, 0);

create table member (
       id serial primary key, 	
       created timestamp default now(),

       username varchar(50) unique,
       email varchar(50) unique,
       passwd varchar(50), /* sha1 of "$id-$password" */       

       phone varchar(20),
       realname varchar(50),
       smail varchar(150),

       doorAccess boolean,  
       adminAccess boolean, /* Admin access via the web interface */
);

create table bankBatch (
       id serial primary key,
       created timestamp default now(),
       member_id integer references member(id),

       rawCsv varchar,       
);


create table payment (
       id serial primary key,
       created timestamp default now(),
       member_id integer references member(id),
       bankBatch_id integer references bankBatch(id),
       
       bankDate date,
       bankComment varchar(50),
       amount numeric(10,2),
       
       userComment varchar(100), /* Info from the administrators about it */

       appoved timestamp, /* Timestamp of the approval of this */
);

create table membershipFee (
       id serial primary key,
       created timestamp default now(),
       member_id integer references member(id),

       amount numeric(10,2),
);

