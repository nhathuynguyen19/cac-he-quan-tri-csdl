use de7slide18
-- 2a
if exists (select * from sys.triggers where name = N'trg_DangKyDuThi_Insert')
begin 
	drop trigger trg_DangKyDuThi_Insert;
end
go

create trigger trg_DangKyDuThi_Insert
on DangKyDuThi
after insert
as
begin
	set nocount on;

	begin try
		update NguoiDuThi
		set SoChungChiDangKy = (
			select count(MaNguoiDuThi)
			from DangKyDuThi
			group by MaNguoiDuThi
		)
		where MaNguoiDuThi = (
			select MaNguoiDuThi from inserted
		)
	end try
	begin catch
		raiserror(N'Lỗi khi chạy trigger for insert dang ky du thi', 16, 1);
		rollback transaction;
	end catch
end
go
-- 2b
if exists (select * from sys.triggers where name = N'trg_DangKyDuThi_Update')
begin 
	drop trigger trg_DangKyDuThi_Update;
end
go

create trigger trg_DangKyDuThi_Update
on DangKyDuThi
after update
as
begin
	set nocount on;

	begin try
		update NguoiDuThi
		set SoChungChiThiDat = (
			select count(*)
			from DangKyDuThi d
			join ChungChi c
			on d.MaChungChi = c.MaChungChi
			where d.MaNguoiDuThi = (
				select top 1 MaNguoiDuThi from inserted
			) and KetQuaThi >= c.MucDiemThiDat
		)
		where MaNguoiDuThi = (
			select top 1 MaNguoiDuThi from inserted
		)
	end try
	begin catch
		raiserror(N'Lỗi khi chạy trigger for update dang ky du thi', 16, 1);
		rollback transaction;
	end catch
end
go
-- 3a
if exists (select * from sys.procedures where name = N'proc_DangKyDuThi_BoSung')
begin 
	drop procedure proc_DangKyDuThi_BoSung;
end
go

create procedure proc_DangKyDuThi_BoSung (
	@MaNguoiDuThi int, 
	@MaChungChi nvarchar(50), 
	@ThongBao nvarchar(255) output 
)
as
begin
	set nocount on;
	set @ThongBao = N'';

	-- kiem tra nguoi du thi
	if not exists (select * from NguoiDuThi where MaNguoiDuThi = @MaNguoiDuThi)
	begin
		set @ThongBao = N'Khong ton tai nguoi du thi';
		raiserror(@ThongBao, 16, 1);
		return;

	end

	-- kiem tra chung chi
	if not exists (select * from ChungChi where MaChungChi = @MaChungChi)
	begin
		set @ThongBao = N'Khong ton tai chung chi';
		raiserror(@ThongBao, 16, 1);
		return;
	end

	-- kiem tra dang ky
	if exists (select * from DangKyDuThi where MaChungChi = @MaChungChi and MaNguoiDuThi = @MaNguoiDuThi)
	begin
		set @ThongBao = N'Nguoi du thi da dang ky';
		raiserror(@ThongBao, 16, 1);
		return;
	end

	-- chen
	begin try
		begin transaction;
			insert into DangKyDuThi(MaNguoiDuThi, MaChungChi)
			values (@MaNguoiDuThi, @MaChungChi);
		commit;
		return;
	end try
	begin catch
		if @@TRANCOUNT > 0 rollback transaction;
		set @ThongBao = N'Loi khi dang ky';
		raiserror(@ThongBao, 16, 1);
		return;
	end catch
end
go
-- 3b
if exists (select * from sys.procedures where name = N'proc_DangKyDuThi_CapNhatKetQuaThi')
begin 
	drop procedure proc_DangKyDuThi_CapNhatKetQuaThi;
end
go

create procedure proc_DangKyDuThi_CapNhatKetQuaThi (
	@MaNguoiDuThi int, 
	@MaChungChi nvarchar(50), 
	@KetQuaThi int, 
	@ThongBao nvarchar(255) output
)
as
begin
	set nocount on;
	set @ThongBao = N'';

	-- kiem tra ket qua
	if (@KetQuaThi < 0)
	begin
		set @ThongBao = N'Diem khong hop le';
		raiserror(@ThongBao, 16, 1);
		return;
	end

	-- kiem tra nguoi du thi
	if not exists (select * from NguoiDuThi where MaNguoiDuThi = @MaNguoiDuThi)
	begin
		set @ThongBao = N'Khong ton tai nguoi du thi';
		raiserror(@ThongBao, 16, 1);
		return;
	end

	-- kiem tra chung chi
	if not exists (select * from ChungChi where MaChungChi = @MaChungChi)
	begin
		set @ThongBao = N'Khong ton tai chung chi';
		raiserror(@ThongBao, 16, 1);
		return;
	end

	-- kiem tra dang ky
	if exists (select * from DangKyDuThi where MaChungChi = @MaChungChi and MaNguoiDuThi = @MaNguoiDuThi)
	begin
		set @ThongBao = N'Nguoi du thi da dang ky';
		raiserror(@ThongBao, 16, 1);
		return;
	end

	-- cap nhat
	begin try
		begin transaction;
			update DangKyDuThi
			set KetQuaThi = @KetQuaThi
			where MaNguoiDuThi = @MaNguoiDuThi and MaChungChi = @MaChungChi
		commit;
		return;
	end try
	begin catch
		if @@TRANCOUNT > 0 rollback transaction;
		set @ThongBao = N'Loi khi cap nhat ket qua thi';
		raiserror(@ThongBao, 16, 1);
		return;
	end catch
end
go
-- 3c
if exists (select * from sys.procedures where name = N'proc_NguoiDuThi_Select')
begin 
	drop procedure proc_NguoiDuThi_Select;
end
go

create procedure proc_NguoiDuThi_Select (
	@HoTen nvarchar(50) = N'', 
	@Page int = 1, 
	@PageSize int = 20, 
	@RowCount int output, 
	@PageCount int output 
)
as
begin
	set nocount on;

	-- so dong
	select @RowCount = (
		select count(*)
		from NguoiDuThi
		where (@HoTen = N'') or (
			HoTen like N'%' + @HoTen + N'%' or
			HoTen like N'%' + @HoTen or
			HoTen like @HoTen + N'%' or
			HoTen like @HoTen or
			HoTen like N''
		)
	)

	-- so trang
	set @PageCount = CEILING(1.0 * @RowCount / @PageSize);
	
	-- tim kiem
	select * 
	from NguoiDuThi
	where (@HoTen = N'') or (
		HoTen like N'%' + @HoTen + N'%' or
		HoTen like N'%' + @HoTen or
		HoTen like @HoTen + N'%' or
		HoTen like @HoTen or
		HoTen like N''

	)
	order by HoTen
	offset @PageSize * (@Page - 1) rows
	fetch next @PageSize row only
end
go
-- 3d
if exists (select * from sys.procedures where name = N'proc_ThongKeSoLuongDangKyTheoNgay')
begin 
	drop procedure proc_ThongKeSoLuongDangKyTheoNgay;
end
go

create procedure proc_ThongKeSoLuongDangKyTheoNgay (
	@TuNgay date,
	@DenNgay date
)
as
begin
	set nocount on;

	-- tao bang ngay
	declare @tblNgay table (
		Ngay date
	);
	declare @i date;
	set @i = @TuNgay;
	while (@i <= @DenNgay)
	begin
		insert into @tblNgay values (@i);
		set @i = DATEADD(day, 1, @i);
	end

	-- thuc hien lenh
	select t1.Ngay as NgayDangKy, ISNULL(t2.SoLuong, 0) as SoLuong
	from @tblNgay t1
	left join (
		select NgayDangKy, count(*) as SoLuong
		from DangKyDuThi
		group by NgayDangKy
	) t2 on t1.Ngay = t2.NgayDangKy
end
go

-- 4a
if exists (select * from sys.objects where name = N'func_DemSoLuongThiDat')
begin 
	drop function func_DemSoLuongThiDat;
end
go

create function func_DemSoLuongThiDat (
	@MaChungChi nvarchar(50)
)
returns int
begin
	declare @i int;

	select @i = count (*)
	from ChungChi c
	join DangKyDuThi d
	on c.MaChungChi = d.MaChungChi
	where KetQuaThi >= MucDiemThiDat

	return @i;
end
go

-- 4b
if exists (select * from sys.objects where name = N'func_ThongKeSoLuongDangKyTheoNgay')
begin 
	drop function func_ThongKeSoLuongDangKyTheoNgay;
end
go

create function func_ThongKeSoLuongDangKyTheoNgay (
	@TuNgay date, 
	@DenNgay date
)
returns @RS table (
	Ngay date,
	SoLuong int
)
begin

	-- Them ngay vao bang tam
	declare @tblTemp table (
		Ngay date
	);

	declare @i date;
	set @i = @TuNgay;
	while (@i <= @DenNgay)
	begin
		insert into @tblTemp values (@i);
		set @i = DATEADD(day, 1, @i);
	end

	-- thuc hien
	insert into @RS
	select t1.Ngay as NgayDangKy, ISNULL(t2.SoLuong, 0) as SoLuong
	from @tblTemp t1
	left join (
		select NgayDangKy, count(*) as SoLuong
		from DangKyDuThi
		group by NgayDangKy
	) t2 on t1.Ngay = t2.NgayDangKy
	return;
end
go