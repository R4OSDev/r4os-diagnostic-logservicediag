LOGDIAG.R4X
===========

LOGDIAG.R4X ist die Log-Service-Diagnose.

Projektstruktur seit 0.51.21:
- `build.zig` baut die Diagnose als eigenes SDK-Projekt.
- `build.zig.zon` bindet `r4os_sdk` als Paket.
- `module.R4MF` beschreibt Artefakt, Zielpfad, R4L-Imports und Contract.

Build:

    cd Code\System\Diagnostics\LogServiceDiag
    ..\..\..\DevTools\Zig\zig.exe build

Ergebnis:

    Code\System\Diagnostics\LogServiceDiag\zig-out\LOGDIAG.R4X

Contract:
- Build-Profil: `Zig/R4XStart`
- R4XStart-Entry: `logdiag_main`
- App-Klasse: `console`
- R4L-Imports: `R4SYS`
- Zielpfad im Image: `C:\R4OS\SOFTWARE\TERMINAL\DIAG\LOGDIAG.R4X`
