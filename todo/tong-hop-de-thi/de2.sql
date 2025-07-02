use master;
go

if EXISTS (select * from sys.databases where name = 'slide2thdt')
BEGIN
    set nocount on;
    alter database slide2thdt set single_user with rollback immediate;
    DROP DATABASE slide2thdt;
END
go

create database slide2thdt;
go

use slide2thdt;
go

create table Movies (
    MovieID NVARCHAR(50) PRIMARY KEY not null,
    Title NVARCHAR(255) NOT NULL,
    ReleaseYear INT NOT NULL,
    Language NVARCHAR(50) NOT NULL,
    Duration INT NOT NULL
);
go

create table People (
    PersonID NVARCHAR(50) PRIMARY KEY not null,
    FullName NVARCHAR(50) NOT NULL,
    BirthDate DATE null,
    DeathDate DATE null
);
go

CREATE TABLE Roles (
    MovieID NVARCHAR(50) NOT NULL,
    PersonID NVARCHAR(50) NOT NULL,
    Role NVARCHAR(50) NOT NULL
    constraint PK_Roles PRIMARY key (MovieID, PersonID),
    constraint FK_Roles_Movies FOREIGN KEY (MovieID) references Movies(MovieID),
    constraint FK_Roles_People FOREIGN KEY (PersonID) REFERENCES People(PersonID)
);
go

-- Thêm dữ liệu vào bảng Movies
INSERT INTO Movies (MovieID, Title, ReleaseYear, Language, Duration) VALUES
('M001', N'Inception', 2010, N'Chinese', 148),
('M002', N'Spirited Away', 2001, N'Japanese', 125),
('M003', N'The Dark Knight', 2008, N'English', 152);

-- Thêm dữ liệu vào bảng People
INSERT INTO People (PersonID, FullName, BirthDate, DeathDate) VALUES
('P001', N'Christopher Nolan', '1970-07-30', NULL),
('P002', N'Hayao Miyazaki', '1941-01-05', NULL),
('P003', N'Leonardo DiCaprio', '1974-11-11', NULL);

-- Thêm dữ liệu vào bảng Roles
INSERT INTO Roles (MovieID, PersonID, Role) VALUES
('M001', 'P001', N'Director'),
('M001', 'P003', N'Actor'),
('M002', 'P002', N'Director'),
('M003', 'P001', N'Director');

-- cau 1 a
if exists (select * from sys.views where name = 'view_Movies_2010')
BEGIN
    DROP VIEW view_Movies_2010;
END
GO

create view view_Movies_2010 AS
select *
from Movies
where ReleaseYear = 2010 and (  Language like N'Chinese' or
                                Language like N'%Chinese' or
                                Language like N'%Chinese%' or
                                Language like N'Chinese%'
                                );
go

-- cau 1 b
UPDATE view_Movies_2010
set Language = N'Japanese'

-- cau 2 a
if exists (select * from sys.procedures where name = 'proc_Roles_Insert')
BEGIN
    DROP PROCEDURE proc_Roles_Insert;
END
GO

create procedure proc_Roles_Insert
    @MovieID NVARCHAR(50),
    @PersonID NVARCHAR(50),
    @Role NVARCHAR(50),
    @Result NVARCHAR(50) OUTPUT
AS
BEGIN
    set nocount on;

    -- chuoi thanh cong
    set @Result = N'';

    -- kiem tra chuoi hop le
    if (@Role not like N'Actor') or (@Role not like N'Actress') or (@Role not like N'Director')
    BEGIN
        set @Result = N'Role khong hop le';
        return;
    END

    -- kiem tra ton tai phim
    if not exists (select * from Movies where MovieID = @MovieID)
    BEGIN
        set @Result = N'Khong ton tai phim';
        return;
    END

    -- kiem tra ton tai nguoi 
    if not exists (select * from People where PersonID = @PersonID)
    BEGIN
        set @Result = N'Khong ton tai nguoi';
        return;
    END

    -- kiem tra vai tro da ton tai doi voi nguoi va phim
    if exists (select * from Roles where (MovieID = @MovieID and @PersonID = PersonID) and (Role = @Role))
    BEGIN
        set @Result = N'Vai tro da ton tai';
        return;
    END

    -- them vai tro moi
    insert into Roles
    VALUES (@MovieID, @PersonID, @Role);
    return;
END
go

-- cau 2 b
if exists (select * from sys.procedures where name = 'proc_People_UpdateDeathDate')
BEGIN
    DROP PROCEDURE proc_People_UpdateDeathDate;
END
GO

create procedure proc_People_UpdateDeathDate
    @PersonID NVARCHAR(50),
    @DeathDate DATE
AS
BEGIN
    set nocount on;

    -- kiem tra ton tai nguoi
    if not exists (select * from People where PersonID = @PersonID)
    BEGIN
        return;
    END

    -- kiem tra ngay mat sau ngay sinh
    if @DeathDate < (select BirthDate from People where PersonID = @PersonID)
        return;
    
    -- cap nhat ngay mat
    update People 
    set DeathDate = @DeathDate
    where PersonID = @PersonID;
end
go

-- cau 2 c
if exists (select * from sys.procedures where name = 'proc_ListMovies')
BEGIN
    DROP PROCEDURE proc_ListMovies;
END
GO

create PROCEDURE proc_ListMovies
    @Page int,
    @PageSize int,
    @RowCount int OUTPUT
as 
BEGIN
    set nocount on;

    set @RowCount = (select count(*) from Movies);

    -- tao bien offset
    declare @Offset int;
    set @Offset = (@Page - 1) * @PageSize;

    -- kiem tra offset khong hop le thi tra ve trang rong
    if @Offset < 0 or @Offset >= @RowCount
    BEGIN
        select * from Movies where 1 = 0;
        return;
    end

    -- lay du lieu theo trang
    select *
    from Movies
    ORDER BY MovieID
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY

    return;
END
go

-- cau 2 d
if exists (SELECT * from sys.procedures where name = 'proc_SummaryByYears')
BEGIN
    DROP PROCEDURE proc_SummaryByYears;
end
GO

create PROCEDURE proc_SummaryByYears
    @FromYear int,
    @ToYear int
AS
BEGIN

    -- tao bang tam
    DECLARE @tblYear table (
        ReleaseYear INT
    )

    -- them cho bang tam
    DECLARE @i int = @FromYear;
    WHILE @i <= @ToYear
    BEGIN
        INSERT INTO @tblYear VALUES (@i);
        set @i = @i + 1;
    END

    -- lay tong so phim theo tung nam ke ca nhung nam khong co phim
    select t1.ReleaseYear, ISNULL(t2.MovieCount, 0) as MovieCount
    from @tblYear as t1
    left join (
        SELECT ReleaseYear, COUNT(*) as MovieCount
        from Movies
        GROUP BY ReleaseYear
        HAVING ReleaseYear BETWEEN @FromYear AND @ToYear
    ) as t2 on t1.ReleaseYear = t2.ReleaseYear;
END
go

-- cau 3

if exists (SELECT * from sys.triggers where name = 'trg_Role_Update')
BEGIN
    DROP trigger trg_Role_Update;
END
go

create TRIGGER trg_Role_Update
on Roles
for UPDATE
AS
BEGIN
    -- kiem tra vai tro hop le
    DECLARE @Role NVARCHAR(50);
    SELECT @Role = Role FROM inserted;
    IF @Role NOT IN (N'Actor', N'Actress', N'Director')
    BEGIN
        RAISERROR('Role khong hop le', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
go

-- cau 4 a
if exists (select * from sys.objects where [type] = 'FN' and name = 'func_CountMoviesByLanguage')
begin 
    drop FUNCTION func_CountMoviesByLanguage;
end
go

create FUNCTION func_CountMoviesByLanguage (
    @Language NVARCHAR(50)
)
RETURNS int 
AS
begin
    declare @Count int;

    select @Count = COUNT(*)
    from Movies
    where Language = @Language;

    RETURN @Count
end
go

if exists (select * from sys.objects where type = 'FN' and name = 'func_GetRoles')
begin
    drop FUNCTION func_GetRoles;
end
go

create function func_GetRoles (
    @MovieID NVARCHAR(50)
) returns table
as 
return (
    select p.FullName, r.Role
    from Roles as r
    join People as p on r.PersonID = p.PersonID
    where r.MovieID = @MovieID
)
go

