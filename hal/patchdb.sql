begin transaction;
alter table accountTransaction add column receiptSent timestamp;
commit;

begin transaction;
insert into account (type_id, id, accountName) values (4, 100001, 'OSAA kontingent');
commit;
