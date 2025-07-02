use de4thdt;
go

alter database de4thdt set single_user with rollback immediate;
drop database de4thdt;

-- xoa views
if exists (select 1 from sys.views where name = 'view_Project_2021')
begin
	drop view view_Project_2021;
end
go

-- xoa procedures
if exists (select 1 from sys.procedures where name = 'proc_Project_Insert')
begin
	drop procedure proc_Project_Insert;
end
go

if exists (select 1 from sys.procedures where name = 'proc_Project_UpdateEndDate')
begin
	drop procedure proc_Project_UpdateEndDate;
end
go

if exists (select 1 from sys.procedures where name = 'proc_ListEmployees')
begin
	drop procedure proc_ListEmployees;
end
go

if exists (select 1 from sys.procedures where name = 'proc_SummaryByMonth')
begin
	drop procedure proc_SummaryByMonth;
end
go

-- xoa triggers
if exists (select 1 from sys.triggers where name = 'trg_Assignment_Insert')
begin
	drop trigger trg_Assignment_Insert;
end
go

-- xoa functions
if exists (select * from sys.objects where name = 'func_CountAssignment')
begin
	drop function func_CountAssignment;
end
go

if exists (select 1 from sys.objects where name = 'func_GetAssignments')
begin
	drop function func_GetAssignments;
end
go

-- cau 1 a
create view view_Project_2021 as
select * 
from Project
where YEAR(StartDate) = 2021 and EndDate is not null
go

-- cau 1 b
update view_Project_2021
set EndDate = NULL
go

-- cau 2 a
create procedure proc_Project_Insert (
	@ProjectID int,
	@ProjectName nvarchar(50),
	@StartDate date,
	@EndDate date = NULL,
	@Result nvarchar(255) output
)
as
begin
	set nocount on;

	-- set rs
	set @Result = N'';

	-- kiem tra id
	if exists (select 1 from Project where ProjectID = @ProjectID)
	begin
		set @Result = N'Ton Tai ma du an';
		return;
	end

	-- truong hop enddate khac null
	if @EndDate is not null and @EndDate < @StartDate
	begin
		set @Result = N'Thoi diem ket thuc khong hop le';
		return;
	end

	-- bo sung
	insert into Project values
	(@ProjectID, @ProjectName, @StartDate, @EndDate)

	return;
end
go

-- Cau 2 b
create procedure proc_Project_UpdateEndDate (
	@ProjectID int,
	@EndDate date
)
as
begin
	set nocount on;

	-- lay thoi diem bat dau
	declare @StartDate date;
	select @StartDate = (
		select StartDate
		from Project
		where ProjectID = @ProjectID
	)

	-- Kiem tra ton tai du an
	if not exists (select 1 from Project where ProjectID = @ProjectID)
	begin
		raiserror(N'Khong ton tai du an', 16, 1);
		return;
	end

	-- kiem tra enddate hop le
	if (@EndDate < @StartDate)
	begin
		raiserror(N'Thoi diem ket thuc khong hop le',16, 1);
		return;
	end

	-- cap nhat
	update Project
	set EndDate = @EndDate
	where ProjectID = @ProjectID

	return;
end
go

-- cau 2 c
create procedure proc_ListEmployees (
	@Page int,
	@PageSize int,
	@RowCount int output
)
as
begin
	set nocount on;

	-- lay tong so luong nhan vien hien co
	select @RowCount = count(*) from Employee;

	-- hien danh sach dang phan trang
	select *
	from Employee
	order by EmployeeID
	offset (@Page - 1) * @PageSize rows
	fetch next @PageSize row only

	return;
end
go

-- cau 2 d
create procedure proc_SummaryByMonth (
	@Year int
)
as
begin
	set nocount on;

	-- tao bang thang
	declare @tblMonths table (
		monthInYear int
	);
	declare @i int = 1;
	while (@i <= 12)
	begin
		insert into @tblMonths values (@i);
		set @i += 1;
	end

	-- lay bang thong ke so luong du an
	select t1.monthInYear, ISNULL(t2.SoLuong, 0)
	from @tblMonths as t1
	left join (
		select MONTH(StartDate) as monthInYear, count(*) as SoLuong
		from Project
		group by MONTH(StartDate)
	) as t2 on t1.monthInYear = t2.monthInYear

	return;
end
go

-- cau 3
create trigger trg_Assignment_Insert
on Assignment
for insert
as
begin
	set nocount on;

	-- lay thoi diem ket thuc du an
	declare @EndDate date;
	select @EndDate = EndDate 
	from inserted as i
	join Project as p on i.ProjectID = p.ProjectID
	where i.ProjectID = p.ProjectID;

	-- lay thoi diem giao viec
	declare @AssignedTime date;
	select @AssignedTime = AssignedTime
	from inserted;

	-- so sanh
	if @EndDate < @AssignedTime
	begin
		raiserror(N'Thoi diem giao viec khong hop le',16, 1);
		rollback transaction;
		return;
	end

	return;
end
go

-- cau 4 a
create function func_CountAssignment (
	@ProjectID int
)
returns int
as 
begin
	-- gia tri tra ve
	declare @rs int;

	select @rs = count(*)
	from Assignment
	where ProjectID = @ProjectID
	group by EmployeeID

	return @rs;
end
go


-- cau 4 b
create function func_GetAssignments (
	@ProjectID int
)
returns table
as
return (
	select e.FullName, e.BirthDate, e.Email, e.Phone, a.AssignedTime, a.Role
	from Assignment as a
	join Employee as e on a.EmployeeID = e.EmployeeID
	where ProjectID = @ProjectID
);
go

