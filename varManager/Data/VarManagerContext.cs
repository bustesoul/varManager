using Microsoft.EntityFrameworkCore;
using varManager.Models;
using varManager.Properties;

namespace varManager.Data
{
    public class VarManagerContext : DbContext
    {
        public DbSet<Dependency> Dependencies { get; set; }
        public DbSet<InstallStatus> InstallStatuses { get; set; }
        public DbSet<Var> Vars { get; set; }
        public DbSet<Scene> Scenes { get; set; }
        public DbSet<SavedDependency> SavedDependencies { get; set; }
        public DbSet<HideFav> HideFavs { get; set; }

        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            if (!optionsBuilder.IsConfigured)
            {
                // Use project directory for database location to match original behavior
                var baseDirectory = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location) ?? System.AppDomain.CurrentDomain.BaseDirectory;
                var dbPath = Path.Combine(baseDirectory, "varManager.db");
                optionsBuilder.UseSqlite($"Data Source={dbPath}");
            }
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // Configure table names to match existing database
            modelBuilder.Entity<Dependency>().ToTable("dependencies");
            modelBuilder.Entity<InstallStatus>().ToTable("installStatus");
            modelBuilder.Entity<Var>().ToTable("vars");
            modelBuilder.Entity<Scene>().ToTable("scenes");
            modelBuilder.Entity<SavedDependency>().ToTable("savedepens");
            modelBuilder.Entity<HideFav>().ToTable("HideFav");

            // Configure property mappings for different naming conventions
            modelBuilder.Entity<Dependency>(entity =>
            {
                entity.Property(e => e.DependencyName).HasColumnName("dependency");
                entity.Property(e => e.VarName).HasColumnName("varName");
            });

            modelBuilder.Entity<SavedDependency>(entity =>
            {
                entity.Property(e => e.DependencyName).HasColumnName("dependency");
                entity.Property(e => e.VarName).HasColumnName("varName");
            });

            // Configure InstallStatus key
            modelBuilder.Entity<InstallStatus>(entity =>
            {
                entity.HasKey(e => e.VarName);
                entity.Property(e => e.VarName).HasColumnName("varName");
                entity.Property(e => e.Installed).HasColumnName("installed");
                entity.Property(e => e.Disabled).HasColumnName("disabled");
            });

            // Configure Scene entity
            modelBuilder.Entity<Scene>(entity =>
            {
                entity.HasKey(e => e.ID);
                entity.Property(e => e.VarName).HasColumnName("varName");
                entity.Property(e => e.AtomType).HasColumnName("atomType");
                entity.Property(e => e.PreviewPic).HasColumnName("previewPic");
                entity.Property(e => e.ScenePath).HasColumnName("scenePath");
                entity.Property(e => e.IsPreset).HasColumnName("isPreset");
                entity.Property(e => e.IsLoadable).HasColumnName("isLoadable");
            });

            // Configure HideFav entity  
            modelBuilder.Entity<HideFav>(entity =>
            {
                entity.HasKey(e => e.VarName);
                entity.Property(e => e.VarName).HasColumnName("varName");
                entity.Property(e => e.Hide).HasColumnName("hide");
                entity.Property(e => e.Fav).HasColumnName("fav");
            });

            // Configure Var entity with proper column mappings
            modelBuilder.Entity<Var>(entity =>
            {
                entity.HasKey(e => e.VarName);
                entity.Property(e => e.VarName).HasColumnName("varName");
                entity.Property(e => e.CreatorName).HasColumnName("creatorName");
                entity.Property(e => e.PackageName).HasColumnName("packageName");
                entity.Property(e => e.MetaDate).HasColumnName("metaDate");
                entity.Property(e => e.VarDate).HasColumnName("varDate");
                entity.Property(e => e.Version).HasColumnName("version");
                entity.Property(e => e.Description).HasColumnName("description");
                entity.Property(e => e.Morph).HasColumnName("morph");
                entity.Property(e => e.Cloth).HasColumnName("cloth");
                entity.Property(e => e.Hair).HasColumnName("hair");
                entity.Property(e => e.Skin).HasColumnName("skin");
                entity.Property(e => e.Pose).HasColumnName("pose");
                entity.Property(e => e.Scene).HasColumnName("scene");
                entity.Property(e => e.Script).HasColumnName("script");
                entity.Property(e => e.Plugin).HasColumnName("plugin");
                entity.Property(e => e.Asset).HasColumnName("asset");
                entity.Property(e => e.Texture).HasColumnName("texture");
                entity.Property(e => e.Look).HasColumnName("look");
                entity.Property(e => e.SubScene).HasColumnName("subScene");
                entity.Property(e => e.Appearance).HasColumnName("appearance");
                entity.Property(e => e.DependencyCnt).HasColumnName("dependencyCnt");
            });

            base.OnModelCreating(modelBuilder);
        }

        // Create views as queryable properties
        public IQueryable<VarsView> VarsView => 
            from v in Vars
            join i in InstallStatuses on v.VarName equals i.VarName into installJoin
            from install in installJoin.DefaultIfEmpty()
            select new VarsView
            {
                VarName = v.VarName,
                CreatorName = v.CreatorName,
                PackageName = v.PackageName,
                MetaDate = v.MetaDate,
                VarDate = v.VarDate,
                Version = v.Version,
                Description = v.Description,
                VarPath = "", // No varPath in existing schema
                Fsize = 0.0, // No file size in existing schema  
                Scenes = v.Scene ?? 0,
                Looks = v.Look ?? 0,
                Clothing = v.Cloth ?? 0,
                Hairstyle = v.Hair ?? 0,
                Plugins = v.Plugin ?? 0,
                Assets = v.Asset ?? 0,
                Morphs = v.Morph ?? 0,
                Pose = v.Pose ?? 0,
                Skin = v.Skin ?? 0,
                Installed = install != null && install.Installed,
                Disabled = install != null && install.Disabled
            };

        public IQueryable<ScenesView> ScenesView =>
            from s in Scenes
            join v in Vars on s.VarName equals v.VarName into varJoin
            from var in varJoin.DefaultIfEmpty()
            join i in InstallStatuses on s.VarName equals i.VarName into installJoin
            from install in installJoin.DefaultIfEmpty()
            join h in HideFavs on s.VarName equals h.VarName into hideFavJoin
            from hideFav in hideFavJoin.DefaultIfEmpty()
            select new ScenesView
            {
                VarName = s.VarName,
                AtomType = s.AtomType,
                IsPreset = s.IsPreset,
                ScenePath = s.ScenePath,
                PreviewPic = s.PreviewPic,
                CreatorName = var != null ? var.CreatorName : null,
                PackageName = var != null ? var.PackageName : null,
                MetaDate = var != null ? var.MetaDate : null,
                Version = var != null ? var.Version : null,
                Installed = install != null && install.Installed,
                Disabled = install != null && install.Disabled,
                Hide = hideFav != null && hideFav.Hide,
                Fav = hideFav != null && hideFav.Fav
            };
    }

    // View model for VarsView
    public class VarsView
    {
        public string VarName { get; set; } = string.Empty;
        public string? CreatorName { get; set; }
        public string? PackageName { get; set; }
        public DateTime? MetaDate { get; set; }
        public DateTime? VarDate { get; set; }
        public string? Version { get; set; }
        public string? Description { get; set; }
        public string? VarPath { get; set; }
        public double Fsize { get; set; }
        public int Scenes { get; set; }
        public int Looks { get; set; }
        public int Clothing { get; set; }
        public int Hairstyle { get; set; }
        public int Plugins { get; set; }
        public int Assets { get; set; }
        public int Morphs { get; set; }
        public int Pose { get; set; }
        public int Skin { get; set; }
        public bool Installed { get; set; }
        public bool Disabled { get; set; }
    }
}