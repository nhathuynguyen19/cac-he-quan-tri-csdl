use de8slide21
-- cau 2a
if exists (select * from sys.triggers where name = N'trg_BangChamCong_Insert')
begin 
	drop trigger trg_BangChamCong_Insert
end
go

create trigger trg_BangChamCong_Insert
on BangChamCong
after insert
as
begin
	set nocount on;

	-- khai bao bien
	declare @Thang int, @Nam int, @SoNgay int

	-- lay gia tri tu inserted
	select @Thang = Thang, @Nam = Nam
	from inserted

	-- lay so ngay
	set @SoNgay = day(EOMONTH(CONCAT(@Nam, '-', @Thang, '-01')));

	-- chen vao bang cham con nhan vien
	insert into BangChamCongNhanVien(Thang, Nam, MaNhanVien, SoNgayCong)
	select @Thang, @Nam, MaNhanVien, @SoNgay
	from NhanVien
end
go
-- 2b
if exists (select * from sys.triggers where name = N'trg_BangChamCongNhanVien_Update')
begin 
	drop trigger trg_BangChamCongNhanVien_Update
end
go

create trigger trg_BangChamCongNhanVien_Update
on BangChamCongNhanVien
after update
as
begin
	set nocount on;

	-- khai bao bien
	declare @Thang int, @Nam int, @SoNgayCong int

	-- lay gia tri so ngay cong tu update
	select @Thang = Thang, @Nam = Nam, @SoNgayCong = SoNgayCong
	from inserted

	-- kiem tra hop le
	if (@SoNgayCong > day((eomonth(CONCAT(@Nam, '-', @Thang, '-01')))) or @SoNgayCong < 0)
	begin
		rollback transaction;
		raiserror(N'Loi khi cap nhat ngay cong',16, 1);
	end
end
go

-- 3a
if exists (select * from sys.procedures where name = N'proc_BangChamCong_Insert')
begin 
	drop procedure proc_BangChamCong_Insert
end
go

create procedure proc_BangChamCong_Insert (
	@Thang int, 
	@Nam int, 
	@NgayLapBang date, 
	@ThongBao nvarchar(255) output 
)
as
begin
	set nocount on;
	set @ThongBao = N'';

	-- kiem tra thang hop le
	if (@Thang <= 0 or @Thang > 12)
	begin
		set @ThongBao = N'Thang khong hop le'
		raiserror(@ThongBao,16, 1);
		return;
	end

	-- kiem tra nam hop le
	if (@Nam < 0)
	begin
		set @ThongBao = N'Nam khong hop le'
		raiserror(@ThongBao,16, 1);
		return;
	end

	-- kiem tra thang nam da ton tai
	if exists (select * from BangChamCong where Nam = @Nam and Thang = @Thang)
	begin
		set @ThongBao = N'Thang nam da ton tai'
		raiserror(@ThongBao,16, 1);
		return;
	end

	-- chen
	begin try
		begin transaction;
			insert into BangChamCong(Thang, NgayLapBang, Nam)
			values(@Thang, @NgayLapBang, @Nam)
		commit;
		return;
	end try
	begin catch
		if @@TRANCOUNT > 0 rollback transaction;
		set @ThongBao = N'Loi khi chen'
		raiserror(@ThongBao,16, 1);
		return;
	end catch
end
go

-- 3b
if exists (select * from sys.procedures where name = N'proc_BangChamCongNhanVien_Update')
begin 
	drop procedure proc_BangChamCongNhanVien_Update
end
go

create procedure proc_BangChamCongNhanVien_Update (
	@Thang int, 
	@Nam int, 
	@MaNhanVien nvarchar(50), 
	@SoNgayCong int, 
	@ThongBao nvarchar(255) output
)
as
begin
	set nocount on;
	set @ThongBao = N'';
	
	-- kiem tra thang
	if (@Thang <= 0 or @Thang > 12)
	begin
		set @ThongBao = N'Thang khong hop le'
		raiserror(@ThongBao,16, 1);
		return;
	end

	-- kiem tra nam
	if (@Nam < 0)
	begin
		set @ThongBao = N'Nam khong hop le'
		raiserror(@ThongBao,16, 1);
		return;
	end

	-- kiem tra nhan vien ton tai
	if not exists (select * from NhanVien where MaNhanVien = @MaNhanVien)
	begin
		set @ThongBao = N'Nhan vien khong ton tai'
		raiserror(@ThongBao,16, 1);
		return;
	end

	-- kiem tra nhan vien, thang, nam ton tai
	if not exists (select * from BangChamCongNhanVien where Thang = @Thang and MaNhanVien = @MaNhanVien and Nam = @Nam)
	begin
		set @ThongBao = N'Chua co nhan vien voi thang nam'
		raiserror(@ThongBao,16, 1);
		return;
	end
	-- lay so ngay trong thang
	declare @SoNgayTrongThang int;
	set @SoNgayTrongThang = day(EOMONTH(concat(@Nam, '-', @Thang, '-01')));

	-- kiem tra so ngay hop le
	if (@SoNgayCong < 0 or @SoNgayCong > @SoNgayTrongThang)
	begin
		set @ThongBao = N'So ngay cong khong hop le'
		raiserror(@ThongBao,16, 1);
		return;
	end

	-- chen
	begin try
		begin transaction;
			update BangChamCongNhanVien
			set SoNgayCong = @SoNgayCong
			where Thang = @Thang and Nam = @Nam and MaNhanVien = @MaNhanVien
		commit;
		return;
	end try
	begin catch
		if @@TRANCOUNT > 0 rollback transaction;
		set @ThongBao = N'Loi khi cap nhat so ngay cong'
		raiserror(@ThongBao,16, 1);
		return;
	end catch
end
go