-- 2
if exists (select * from sys.triggers where name = N'trg_LopHocPhan_SinhVien_Insert')
begin 
	drop trigger trg_LopHocPhan_SinhVien_Insert;
end
go

create trigger trg_LopHocPhan_SinhVien_Insert
on LopHocPhan_SinhVien
after insert
as
begin
	set nocount on;
	
	begin try
		update LopHocPhan
		set SoSinhVienDangKy = ls.SoLuong
		from LopHocPhan as l
		join (
			select MaLopHocPhan, Count(*) as SoLuong
			from LopHocPhan_SinhVien
			group by MaLopHocPhan
		) as ls on l.MaLopHocPhan = ls.MaLopHocPhan
	end try
	begin catch
		raiserror(N'Lỗi khi cập nhật số lượng đăng ký lớp học phần', 16, 1);
		rollback transaction;
	end catch
end
go
-- 3a
if exists(select * from sys.procedures where name = N'proc_LopHocPhan_SinhVien_Insert')
begin
	drop procedure proc_LopHocPhan_SinhVien_Insert;
end
go

create procedure proc_LopHocPhan_SinhVien_Insert (
	@MaLopHocPhan nvarchar(50),
	@MaSinhVien nvarchar(50),
	@KetQua nvarchar(255) output
) 
as
begin
	set nocount on;
	set @KetQua = N'';

	-- kiem tra lop hoc phan ton tai
	if not exists (select * from LopHocPhan where MaLopHocPhan = @MaLopHocPhan)
	begin
		set @KetQua = N'Không tồn tại lớp học phần';
		raiserror(@KetQua, 16, 1);
		return;
	end

	-- kiem tra sinh vien ton tai
	if not exists (select * from SinhVien where MaSinhVien = @MaSinhVien)
	begin
		set @KetQua = N'Không tồn tại sinh viên';
		raiserror(@KetQua, 16, 1);
		return;
	end

	-- kiem tra da ton tai bieu mau dang ky
	if exists (select * from LopHocPhan_SinhVien where (MaSinhVien = @MaSinhVien and MaLopHocPhan = @MaLopHocPhan))
	begin
		set @KetQua = N'Sinh viên đã đăng ký lớp học phần';
		raiserror(N'Sinh viên đã đăng ký lớp học phần', 16, 1);
		return;
	end

	-- chen du lieu
	begin try
		begin transaction;
			insert into LopHocPhan_SinhVien (MaLopHocPhan, MaSinhVien, NgayDangKy)
			values (@MaLopHocPhan, @MaSinhVien, GETDATE())
		commit;
	end try
	begin catch 
		if @@TRANCOUNT > 0 rollback transaction;
		set @KetQua = N'Lỗi khi sinh viên đăng ký lớp học phần';
		raiserror(@KetQua, 16, 1);
	end catch
	return
end
go
-- 3b
if exists(select * from sys.procedures where name = N'proc_LopHocPhan_SinhVien_SelectByLop')
begin
	drop procedure proc_LopHocPhan_SinhVien_SelectByLop;
end
go

create procedure proc_LopHocPhan_SinhVien_SelectByLop (
	@MaLopHocPhan nvarchar(50),
	@TenLop nvarchar(50)
) 
as
begin
	set nocount on;
	
	-- kiem tra lop hoc phan ton tai
	if not exists (select * from LopHocPhan where MaLopHocPhan = @MaLopHocPhan)
	begin
		raiserror(N'Lớp học phần không tồn tại', 16, 1);
		return;
	end

	-- kiem tra ten lop ton tai
	if not exists (select * from SinhVien where TenLop = @TenLop)
	begin
		raiserror(N'Tên lớp không tồn tại', 16, 1);
		return;
	end

	-- select 
	select s.MaSinhVien, HoTen, NgaySinh, NoiSinh
	from SinhVien s
	join LopHocPhan_SinhVien ls
	on s.MaSinhVien = ls.MaSinhVien
	where TenLop = N'Tin K44A' and ls.MaLopHocPhan = N'L004'
	order by s.HoTen
	return;
end
go
-- 3c
if exists(select * from sys.procedures where name = N'proc_SinhVien_TimKiem')
begin
	drop procedure proc_SinhVien_TimKiem;
end
go

create procedure proc_SinhVien_TimKiem (
	@HoTen nvarchar(50) = N'', 
	@Tuoi int, 
	@SoLuong int output
) 
as
begin
	set nocount on;
	
	select * 
	from SinhVien
	where (
		HoTen like @HoTen or
		HoTen like N'%' + @HoTen or
		HoTen like N'%' + @HoTen + N'%' or
		HoTen like @HoTen + N'%' or
		HoTen Like N''
	) and YEAR(GETDATE()) - YEAR(NgaySinh) >= @Tuoi

	select @SoLuong = count(*)
	from (
		select * 
		from SinhVien
		where (
			HoTen like @HoTen or
			HoTen like N'%' + @HoTen or
			HoTen like N'%' + @HoTen + N'%' or
			HoTen like @HoTen + N'%' or
			HoTen Like N''
		) and YEAR(GETDATE()) - YEAR(NgaySinh) >= @Tuoi
	) s
	return;
end
go
-- 3d
if exists(select * from sys.procedures where name = N'proc_ThongKeDangKyHoc')
begin
	drop procedure proc_ThongKeDangKyHoc;
end
go

create procedure proc_ThongKeDangKyHoc (
	@MaLopHocPhan nvarchar(50), 
	@TuNgay date, 
	@DenNgay date
) 
as
begin
	set nocount on;
	
	-- tao bang ngay
	declare @tblDay table (
		NgayDangKy date
	)

	-- insert tu ngay den ngay vao bang ngay
	declare @i date;
	set @i = @TuNgay

	while (@i <= @DenNgay)
	begin
		insert into @tblDay values (@i);
		set @i = DATEADD(day, 1, @i);
	end

	-- thong ke so luong dang ky cua hoc phan theo tung ngay
	select t1.NgayDangKy, isnull(t2.SoLuong, 0)
	from @tblDay t1
	left join (
		select NgayDangKy, COUNT(*) as SoLuong
		from LopHocPhan_SinhVien
		where MaLopHocPhan = N'L004'
		group by NgayDangKy
	) t2 on t1.NgayDangKy = t2.NgayDangKy
	return;
end
go
-- 4a
if exists(select * from sys.objects where name = N'func_TkeKhoiLuongDangKyHoc')
begin
	drop function func_TkeKhoiLuongDangKyHoc;
end
go

create function func_TkeKhoiLuongDangKyHoc (
	@MaSinhVien nvarchar(50),
	@TuNam int, 
	@DenNam int
)
returns table
as
return (
	select year(NgayDangKy) as NgayDangKy, sum(SoTinChi) as TongSoTinChi
	from LopHocPhan l
	join LopHocPhan_SinhVien ls
	on l.MaLopHocPhan = ls.MaLopHocPhan
	where MaSinhVien = @MaSinhVien and (year(NgayDangKy) >= @TuNam and year(NgayDangKy) <= @DenNam)
	group by year(NgayDangKy)
)
go
-- 4b
if exists(select * from sys.objects where name = N'func_TkeKhoiLuongDangKyHoc_DayDuNam')
begin
	drop function func_TkeKhoiLuongDangKyHoc_DayDuNam;
end
go

create function func_TkeKhoiLuongDangKyHoc_DayDuNam (
	@MaSinhVien nvarchar(50),
	@TuNam int, 
	@DenNam int 
)
returns @Result table (
	NamDangKy int,
	TongSoTinChi int
)
as
begin
	-- tao bang tam
	declare @tblNam table (
		NamDangKy int
	)

	-- insert tu nam den nam vao bang nam
	declare @i int;
	set @i = @TuNam

	while (@i <= @DenNam)
	begin
		insert into @tblNam values (@i);
		set @i = @i + 1
	end

	-- return
	insert into @Result
	select t1.NamDangKy as NamDangKy, ISNULL(t2.TongSoTinChi, 0) as TongSoTinChi
	from @tblNam t1
	left join (
		select year(NgayDangKy) as NamDangKy, sum(SoTinChi) as TongSoTinChi
		from LopHocPhan l
		join LopHocPhan_SinhVien ls
		on l.MaLopHocPhan = ls.MaLopHocPhan
		where MaSinhVien = @MaSinhVien and (year(NgayDangKy) >= @TuNam and year(NgayDangKy) <= @DenNam)
		group by year(NgayDangKy)
	) t2 on t1.NamDangKy = t2.NamDangKy
	return;
end
go
-- 5
create login user_23T1080025 with password = '123456';
use de6slide15;
create user user_23T1080025 for login user_23T1080025;
grant select, update on SinhVien to user_23T1080025;
grant execute to user_23T1080025;
go