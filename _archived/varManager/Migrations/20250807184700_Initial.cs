using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace varManager.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "dependencies",
                columns: table => new
                {
                    ID = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    varName = table.Column<string>(type: "TEXT", maxLength: 255, nullable: true),
                    dependency = table.Column<string>(type: "TEXT", maxLength: 255, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_dependencies", x => x.ID);
                });

            migrationBuilder.CreateTable(
                name: "HideFav",
                columns: table => new
                {
                    varName = table.Column<string>(type: "TEXT", maxLength: 255, nullable: false),
                    ID = table.Column<int>(type: "INTEGER", nullable: false),
                    hide = table.Column<bool>(type: "INTEGER", nullable: false),
                    fav = table.Column<bool>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HideFav", x => x.varName);
                });

            migrationBuilder.CreateTable(
                name: "installStatus",
                columns: table => new
                {
                    varName = table.Column<string>(type: "TEXT", maxLength: 255, nullable: false),
                    installed = table.Column<bool>(type: "INTEGER", nullable: false),
                    disabled = table.Column<bool>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_installStatus", x => x.varName);
                });

            migrationBuilder.CreateTable(
                name: "savedepens",
                columns: table => new
                {
                    ID = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    varName = table.Column<string>(type: "TEXT", maxLength: 255, nullable: true),
                    dependency = table.Column<string>(type: "TEXT", maxLength: 255, nullable: true),
                    SavePath = table.Column<string>(type: "TEXT", maxLength: 500, nullable: true),
                    ModiDate = table.Column<DateTime>(type: "TEXT", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_savedepens", x => x.ID);
                });

            migrationBuilder.CreateTable(
                name: "scenes",
                columns: table => new
                {
                    ID = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    varName = table.Column<string>(type: "TEXT", maxLength: 255, nullable: true),
                    atomType = table.Column<string>(type: "TEXT", maxLength: 255, nullable: true),
                    previewPic = table.Column<string>(type: "TEXT", maxLength: 255, nullable: true),
                    scenePath = table.Column<string>(type: "TEXT", maxLength: 255, nullable: true),
                    isPreset = table.Column<bool>(type: "INTEGER", nullable: false),
                    isLoadable = table.Column<bool>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_scenes", x => x.ID);
                });

            migrationBuilder.CreateTable(
                name: "vars",
                columns: table => new
                {
                    varName = table.Column<string>(type: "TEXT", maxLength: 255, nullable: false),
                    creatorName = table.Column<string>(type: "TEXT", maxLength: 255, nullable: true),
                    packageName = table.Column<string>(type: "TEXT", maxLength: 255, nullable: true),
                    metaDate = table.Column<DateTime>(type: "TEXT", nullable: true),
                    varDate = table.Column<DateTime>(type: "TEXT", nullable: true),
                    version = table.Column<string>(type: "TEXT", maxLength: 50, nullable: true),
                    description = table.Column<string>(type: "TEXT", nullable: true),
                    morph = table.Column<int>(type: "INTEGER", nullable: true),
                    cloth = table.Column<int>(type: "INTEGER", nullable: true),
                    hair = table.Column<int>(type: "INTEGER", nullable: true),
                    skin = table.Column<int>(type: "INTEGER", nullable: true),
                    pose = table.Column<int>(type: "INTEGER", nullable: true),
                    scene = table.Column<int>(type: "INTEGER", nullable: true),
                    script = table.Column<int>(type: "INTEGER", nullable: true),
                    plugin = table.Column<int>(type: "INTEGER", nullable: true),
                    asset = table.Column<int>(type: "INTEGER", nullable: true),
                    texture = table.Column<int>(type: "INTEGER", nullable: true),
                    look = table.Column<int>(type: "INTEGER", nullable: true),
                    subScene = table.Column<int>(type: "INTEGER", nullable: true),
                    appearance = table.Column<int>(type: "INTEGER", nullable: true),
                    dependencyCnt = table.Column<int>(type: "INTEGER", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_vars", x => x.varName);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "dependencies");

            migrationBuilder.DropTable(
                name: "HideFav");

            migrationBuilder.DropTable(
                name: "installStatus");

            migrationBuilder.DropTable(
                name: "savedepens");

            migrationBuilder.DropTable(
                name: "scenes");

            migrationBuilder.DropTable(
                name: "vars");
        }
    }
}
