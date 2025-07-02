use master;
go

if exists (select * from sys.databases where name = 'de3thdt')
begin
	alter database de3thdt set single_user with rollback immediate;
	drop database de3thdt;
end
go

create database de3thdt;
go

use de3thdt;
go

create table Examinees (
	ExamineeID int primary key not null,
	FullName nvarchar(50) not null,
	BirthDate date not null,
	Email nvarchar(50) not null,
	Phone nvarchar(50) not null
);
go

create table Certificates (
	CertificateID nvarchar(50) primary key not null,
	CertificateName nvarchar(100) not null,
	TrainingMonths int not null,
	TuitionFee money not null
);
go

create table Registrations (
	ExamineeID int not null,
	CertificateID nvarchar(50) not null,
	RegisteredDate date not null,
	Discount decimal(5, 2) not null,
	constraint PK_Registrations primary key (ExamineeID, CertificateID),
	constraint FK_Registrations_Examinees foreign key (ExamineeID) references Examinees(ExamineeID),
	constraint FK_Registrations_Certificates foreign key (CertificateID) references Certificates(CertificateID)
);
go

-- Chèn dữ liệu mẫu vào bảng Examinees
INSERT INTO Examinees (ExamineeID, FullName, BirthDate, Email, Phone)
VALUES 
(1, N'Nguyễn Văn A', '2000-01-15', 'nguyenvana@example.com', '0901234567'),
(2, N'Nguyễn Văn B', '2001-01-16', 'nguyenvanb@example.com', '0907834567');

-- Chèn dữ liệu mẫu vào bảng Certificates
INSERT INTO Certificates (CertificateID, CertificateName, TrainingMonths, TuitionFee)
VALUES 
('C001', N'Lập trình C++ cơ bản', 1, 1400000),
('C002', N'Lập trình Python cơ bản', 1, 1300000);

-- Chèn dữ liệu mẫu vào bảng Registrations
INSERT INTO Registrations (ExamineeID, CertificateID, RegisteredDate, Discount)
VALUES 
(1, 'C001', '2025-05-23', 10.00),
(2, 'C001', '2025-05-23', 10.00),
(1, 'C002', '2025-06-23', 10.00);

-- cau 1 a
if exists (select * from sys.views where name = 'view_Certificates_InAMonth')
begin
	drop view view_Certificates_InAMonth;
end
go

create view view_Certificates_InAMonth as
select *
from Certificates
where TrainingMonths = 1 and TuitionFee < 1500000;
go

--select * from view_Certificates_InAMonth;
--go

-- cau 1 b
update view_Certificates_InAMonth
set TuitionFee = 1500000
go

--select * from Certificates;
--go

-- cau 2 a
if exists (select * from sys.procedures where name = 'proc_AddRegistration')
begin
	drop procedure proc_AddRegistration;
end
go

create procedure proc_AddRegistration (
	@ExamineeID int,
	@CertificateID nvarchar(50),
	@RegisteredDate date,
	@Discount decimal(5,2),
	@Result nvarchar(255) OUTPUT
)
as
begin
	set nocount on;
	-- dinh nghia tra ve
	set @Result = N'';

	-- kiem tra ton tai ExamineeID
	if not exists (select * from Examinees where ExamineeID = @ExamineeID)
	begin
		set @Result = N'khong ton tai Examinee';
		return;
	end

	-- kiem tra ton tai @CertificateID
	if not exists (select * from Certificates where CertificateID = @CertificateID)
	begin
		set @Result = N'khong ton tai Certificate';
		return;
	end

	-- kiem tra ton tai Dang ky khoa hoc
	if exists (select * from Registrations where CertificateID = @CertificateID and ExamineeID = @ExamineeID)
	begin
		set @Result = N'Da dang ky';
		return;
	end

	-- kiem tra discount hop le
	if (@Discount < 0 or @Discount > 1)
	begin
		set @Result = N'discount khong hop le';
		return;
	end

	-- insert
	insert into Registrations
	values (@ExamineeID, @CertificateID, @RegisteredDate, @Discount);
	
	return;
end
go

--declare @t nvarchar(255) = N'';
--exec proc_AddRegistration 1, N'C002', '2000-01-01', 1, @Result = @t output;
--select @t as cau2;
--go

-- cau 2 b
if exists (select * from sys.procedures where name = 'proc_Examinees_Delete ')
begin
	drop procedure proc_Examinees_Delete ;
end
go

create procedure proc_Examinees_Delete (
	@ExamineeID int
)
as
begin
	-- kiem tra co ton tai nguoi dang ky
	if not exists (select * from Examinees where ExamineeID = @ExamineeID)
	begin
		return;
	end

	-- kiem tra da dang ky chung chi chua
	if exists (select * from Registrations where ExamineeID = @ExamineeID)
	begin
		return;
	end

	-- xoa nguoi dang ky
	delete from Examinees where ExamineeID = @ExamineeID
	return;
end
go

--exec proc_Examinees_Delete 2;
--go

--select * from Examinees
--go

-- cau 2 c
if exists (select * from sys.procedures where name = 'proc_ListExaminees ')
begin
	drop procedure proc_ListExaminees;
end
go

create procedure proc_ListExaminees (
	@Page int, 
    @PageSize int, 
    @RowCount int output
)
as
begin
	-- set so trang
	select @RowCount = (
		select count(ExamineeID)
		from Examinees
	);

	-- neu so trang bang 0
	if @Page <= 0
	begin
		raiserror(N'Số trang không hợp lệ', 16, 1);
		return;
	end

	-- select 
	select * 
	from Examinees
	order by ExamineeID
	offset (@Page - 1) * @PageSize rows
	fetch next @PageSize rows only;

	return;
end
go

--declare @t int;
--exec proc_ListExaminees 0, 1, @RowCount = @t output;
--select @t as cau2c
--go

-- cau 2 d
if exists (select * from sys.procedures where name = 'proc_SummaryByMonth')
begin
	drop procedure proc_SummaryByMonth;
end
go

create procedure proc_SummaryByMonth (
	@Year int
)
as
begin
	-- table thang
	declare @tblMonths table (
		monthInYear int
	);

	-- tao thang
	declare @i int = 1
	while (@i <= 12) 
	begin
		insert into @tblMonths values (@i);
		set @i += 1;
	end

	-- cau lenh thong ke so luong dang ky du thi
	select t1.monthInYear, isnull(t2.SoLuong, 0) as SoLuong
	from @tblMonths as t1
	left join (
		select month(RegisteredDate) as monthInYear, count(*) as SoLuong
		from Registrations
		group by month(RegisteredDate)
	) as t2 on t1.monthInYear = t2.monthInYear

end
go

--exec proc_SummaryByMonth 2025;
--go

-- cau 3
if exists (select * from sys.triggers where name = 'trg_Registrations_Update')
begin
	drop trigger trg_Registrations_Update;
end
go

create trigger trg_Registrations_Update
on Registrations
for update
as
begin
	-- kiem tra cap nhat discount
	declare @disCount decimal(5, 2);
	select @disCount = Discount from inserted;

	if @disCount < 0 or @disCount > 0
	begin
		raiserror('Discout khong hop le', 16, 1);
		rollback transaction;
		return;
	end
end
go

--update Registrations
--set Discount = 2
--where ExamineeID = 1
--go

-- cau 4 a
if exists (select * from sys.objects where name = 'func_CountRegistrations' and type = 'FN')
begin
	drop function func_CountRegistrations;
end
go

create function func_CountRegistrations (
	@Month int
)
returns int
as
begin
	declare @rs int;

	select @rs = count(*)
	from Registrations
	where month(RegisteredDate) = @Month
	
	return @rs;
end
go

--select dbo.func_CountRegistrations(6);
--go

-- cau 4 b
if exists (select * from sys.objects where name = 'func_GetExaminees' and type = 'FN')
begin
	drop function func_GetExaminees;
end
go

create function func_GetExaminees (
	@CertificateID nvarchar(50)
)
returns table
as
return (
	select e.ExamineeID, e.FullName, e.BirthDate, e.Email, e.Phone
	from Registrations as r
	join Examinees as e on r.ExamineeID = e.ExamineeID
	where CertificateID = @CertificateID
)
go

--select * from func_GetExaminees(N'C002');
--go