-- tao database
USE master;
GO

if exists (select * from sys.databases where name = 'slide1thdt')
begin
	set nocount on;
	alter database slide1thdt set single_user with rollback immediate;
    drop database slide1thdt;
end
GO

create database slide1thdt;
GO

-- su dung database
use slide1thdt;
go

-- tao bang sinh vien
create table Students (
    StudentID nvarchar(50) primary key not null,
    StudentName nvarchar(50) not null,
    BirthDate date not null,
    PlaceOfBirth nvarchar(50) not null,
    Email nvarchar(50) null,
    Phone nvarchar(50) null
);
go

-- tao bang mon hoc
create table Subjects (
    SubjectID nvarchar(50) primary key not null,
    SubjectName nvarchar(100) not null,
    NumberOfCredits int not null
);
GO

-- tao bang ket qua hoc tap
create table StudyResults (
    StudentID nvarchar(50) not null,
    SubjectID nvarchar(50) not null,
    Score decimal(5,2) null,
    CONSTRAINT PK_StudyResults PRIMARY KEY (StudentID, SubjectID),
    CONSTRAINT FK_StudyResults_Students FOREIGN KEY (StudentID) REFERENCES Students(StudentID),
    CONSTRAINT FK_StudyResults_Subjects FOREIGN KEY (SubjectID) REFERENCES Subjects(SubjectID)
);
GO

-- chen du lieu cho bang sinh vien
INSERT INTO Students (StudentID, StudentName, BirthDate, PlaceOfBirth, Email, Phone)
VALUES 
    ('SV006', 'Nguyen Thi A', '2000-03-10', 'Hue', 'nta@gmail.com', '0911111111'),
    ('SV007', 'Tran Van B', '2000-06-22', 'Da Nang', 'tvb@gmail.com', '0922222222'),
    ('SV008', 'Le Thi C', '2000-09-14', 'Ha Noi', 'ltc@gmail.com', '0933333333'),
    ('SV009', 'Pham Van D', '2000-11-30', 'Hue', 'pvd@gmail.com', '0944444444'),
    ('SV010', 'Do Thi E', '2000-01-25', 'TPHCM', 'dte@gmail.com', '0955555555'),
    ('SV011', 'Bui Van F', '2000-04-18', 'Quang Nam', 'bvf@gmail.com', '0966666666'),
    ('SV012', 'Hoang Thi G', '2000-12-12', 'Hue', 'htg@gmail.com', '0977777777'),
    ('SV013', 'Dang Van H', '2000-08-05', 'Nha Trang', 'dvh@gmail.com', '0988888888'),
    ('SV014', 'Vo Thi I', '2000-10-01', 'Hue', 'vti@gmail.com', '0999999999'),
    ('SV015', 'Mai Van J', '2000-10-07', 'Da Nang', 'mvj@gmail.com', '0900000000');
GO


-- chen du lieu mon
INSERT INTO Subjects
VALUES 
	(N'SJ001', N'Toan Roi Rac', 3);
go
-- Cau 1a: tao khung nhìn view_Students_2000 co chuc nang lay duoc thong tin cua cac sinh vien sinh nam 2000 tai Hue
if exists (select * from sys.views where name = 'view_Students_2000')
begin
    drop view view_Students_2000;
end
GO

create view view_Students_2000 as
select *
FROM Students
where Year(BirthDate) = 2000 and	((PlaceOfBirth like 'Hue') or 
									(PlaceOfBirth like '%Hue') or 
									(PlaceOfBirth like '%Hue%') or
									(PlaceOfBirth like '%.Hue%'));
go

-- test cau 1a
-- select * from view_Students_2000

-- Cau 1b: Thong qua khung nhin tren, cap nhat noi sinh cua cac sinh vien sinh nam 2000 tai Hue thanh Thua Thien Hue
update view_Students_2000
set PlaceOfBirth = 'Thua Thien Hue'
where	(PlaceOfBirth like 'Hue') or 
		(PlaceOfBirth like '%Hue') or 
		(PlaceOfBirth like '%Hue%') or
		(PlaceOfBirth like '%.Hue%');
go

-- Cau 2a tao thu tuc
if exists (select * from sys.procedures where name = 'proc_AddStudyResult')
	drop procedure proc_AddStudyResult;
go

create procedure proc_AddStudyResult
	@StudentID nvarchar(50),
	@SubjectID nvarchar(50),
	@Score decimal(5, 2),
	@Result nvarchar(255) output
as
begin
	set nocount on;

	-- set rs true
	set @Result = N'';

	-- kiem tra diem 0 - 10
	if @Score < 0 or @Score > 10
	begin
		set @Result = N'Diem khong hop le';
		return;
	end

	-- kiem tra sinh vien ton tai
	if not exists (select * from Students where StudentID = @StudentID)
	begin
		set @Result = N'Khong ton tai sinh vien';
		return;
	end
	
	-- kiem tra mon hoc ton tai
	if not exists (select * from Subjects where SubjectID = @SubjectID)
	begin
		set @Result = N'Khong ton tai mon hoc';
		return;
	end
	
	-- kiem tra da ton tai diem mon hoc cua sinh vien
	if exists (select * from StudyResults where (StudentID = @StudentID) and (SubjectID = @SubjectID))
	begin
		set @Result = N'Da ton tai diem';
		return;
	end

	insert into StudyResults
	values (@StudentID, @SubjectID, @Score);
end
go

-- test cau 2a
-- declare @t nvarchar(50) = N'';
-- exec proc_AddStudyResult @StudentID = N'SV001', @SubjectID = N'SJ001', @Score = 10, @Result = @t output;
-- select @t;
-- go

-- cau 2b
if exists (select * from sys.procedures where name = 'proc_DeleteStudent')
begin
    drop PROCEDURE proc_DeleteStudent;
end
GO

create procedure proc_DeleteStudent
	@StudentID nvarchar(50)
AS
BEGIN
	set nocount on;

	if exists (select * from StudyResults where StudentID = @StudentID)
	BEGIN
		return;
	END

	DELETE from Students
	where StudentID = @StudentID;
end
go

-- test cau 2b
-- proc_DeleteStudent @StudentID = N'SV002';
-- select * from Students;
-- go

-- cau 2c
if exists (select * from sys.procedures where name = 'proc_ListStudents')
begin
	drop procedure proc_ListStudents;
end
GO

create procedure proc_ListStudents
	@Page int,
	@PageSize int,
	@RowCount int output
as
begin
	set nocount on;

	-- Tổng số sinh viên
	select @RowCount = count(*) from Students;

	-- Hiển thị danh sách theo trang
	select *
	from Students
	order by StudentID
	offset (@Page - 1) * @PageSize rows
	fetch next @PageSize rows only;
end
go

-- cau 2d
if exists (select * from sys.procedures where name = 'proc_CountStudentsByBirthMonth')
begin
	drop procedure proc_CountStudentsByBirthMonth;
end
GO

create procedure proc_CountStudentsByBirthMonth
	@Year INT
as 
BEGIN
	set nocount on;

	DECLARE @tblMonth table (
		monthYear int
	)

	declare @i int = 1;
	while @i <= 12
	BEGIN
		insert into @tblMonth values (@i);
		set @i = @i + 1;
	END

	-- tinh tong sinh vien theo thang sinh
	select t1.monthYear, isnull(StudentCount, 0) as StudentCount
	from @tblMonth as t1
	left join (
		select MONTH(BirthDate) as monthYear, COUNT(*) as StudentCount
		from Students
		where Year(BirthDate) = @Year
		group by Month(BirthDate)
	) as t2 on t1.monthYear = t2.monthYear
END
go

-- Câu 3: (1,5 đ) Viết trigger trg_Subjects_Update để xử lý trường hợp khi cập nhật dữ liệu 
-- của cột NumberOfCredits trong bảng Subjects, trong đó chỉ cho phép cập nhật nếu số tín chỉ 
-- (NumberOfCredits) của môn học phải là giá trị từ 2 đến 4. 

if exists (select * from sys.triggers where name = 'trg_Subjects_Update')
begin
	drop trigger trg_Subjects_Update;
end
GO

create trigger trg_Subjects_Update
on Subjects
for update
as
begin
	set nocount on;

	declare @NumberOfCredits int;
	select @NumberOfCredits = NumberOfCredits from inserted;

	if @NumberOfCredits < 2 or @NumberOfCredits > 4
	begin
		rollback transaction;
		raiserror('So tin chi phai tu 2 den 4', 16, 1);
	end
end
GO

-- Câu 4: 
-- a. (1đ) Viết hàm func_CountStudents(@PlaceOfBirth nvarchar(50)) có chức năng 
-- trả về giá trị cho biết số lượng sinh viên được sinh tại @PlaceOfBirth 

if exists (select * from sys.objects where type = 'FN' and name = 'func_CountStudents')
begin
	drop function func_CountStudents;
end
GO

create function func_CountStudents(@PlaceOfBirth nvarchar(50))
returns int
as
begin
	declare @Count int;

	select @Count = count(*)
	from Students
	where PlaceOfBirth = @PlaceOfBirth;

	return @Count;
end
go

-- b. (1,5 đ) Viết hàm func_GetStudyResults(@StudentID nvarchar(50)) có chức năng 
-- trả về một bảng cho biết kết quả học các môn học của sinh viên có mã là @StudentID.

if exists (select * from sys.objects where type = 'FN' and name = 'func_GetStudyResults')
begin
	drop function func_GetStudyResults;
end
GO

create function func_GetStudyResults(@StudentID nvarchar(50))
returns table
as
return
(
	select s.StudentID, s.StudentName, sr.SubjectID, sub.SubjectName, sr.Score
	from Students s
	join StudyResults sr on s.StudentID = sr.StudentID
	join Subjects sub on sr.SubjectID = sub.SubjectID
	where s.StudentID = @StudentID
);
go
