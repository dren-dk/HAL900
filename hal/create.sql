/*
 createuser -s -d -U postgres -P hal
 createdb -U hal hal
 psql -U hal < create.sql

 ... or pg_restore -d hal -U hal -c latest.pg 
*/

begin transaction;

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
       adminAccess boolean /* Admin access via the web interface */
);

create table accountType (
       id integer primary key,
       created timestamp default now(),
       typeName varchar(50),
);
insert into accountType (id, typeName) values (1, 'Main organizational account');
insert into accountType (id, typeName) values (2, 'Personal dues and purchases');
insert into accountType (id, typeName) values (3, 'Loans');

create table account (
       id serial primary key,
       created timestamp default now(),
       owner_id integer references member(id),
       type_id integer references accountType(id) not null,
       
       accountName varchar(50)
);
insert into account (type_id, accountName) values (1, 'OSAA kassebeholdning');

create table accountTransaction (
       id serial primary key,
       created timestamp default now(),

       source_account_id integer not null references account(id),
       target_account_id integer not null references account(id),
       check (source_account_id <> target_account_id),

       amount numeric(10,2) check (amount > 0),

       comment varchar(50),
}


create table bankBatch (
       id serial primary key,
       created timestamp default now(),
       member_id integer references member(id),

       rawCsv varchar,
);

create table bankTransaction (
       id serial primary key,
       created timestamp default now(),
       member_id integer references member(id),
       bankBatch_id integer references bankBatch(id) not null,
       
       bankDate date,
       bankComment varchar(50),
       amount numeric(10,2),

       transaction_id integer references accountTransaction(id),
       userComment varchar(100), /* Info from the administrators about it */
);

commit;
