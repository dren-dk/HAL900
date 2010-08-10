begin transaction;
alter table accountTransaction add column receiptSent timestamp;
commit;

begin transaction;
insert into account (type_id, id, accountName) values (4, 100001, 'OSAA kontingent');
commit;

begin transaction;
create table rfid (
       id serial primary key,
       created timestamp default now(),
       updated timestamp default now(),

       rfid integer unique not null,
       owner_id integer references member(id) not null,
       pin bigint,
       lost boolean default false
);

create table doorTransaction (
       id serial primary key,
       created timestamp default now(),
       updated timestamp default now(),

       rfid_id integer references rfid(id) not null,

       hash bigint not null, 
       kind char(1) not null
);
commit;

begin transaction;
alter table rfid add column lost boolean default false;
commit;

begin transaction;
alter table member add column lastNagMail timestamp;
commit;
