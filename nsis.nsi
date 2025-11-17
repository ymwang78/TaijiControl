!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"

; Basic configuration
Name "WinPython 3.12"
OutFile "WinPython312_Setup.exe"
InstallDir "C:\TaiJiControl\WinPy312"

; Set compression method
SetCompressor /SOLID lzma

; Version information
VIProductVersion "1.0.0.0"
VIAddVersionKey "ProductName" "WinPython 3.12"
VIAddVersionKey "CompanyName" "WinPython"
VIAddVersionKey "FileVersion" "1.0.0.0"
VIAddVersionKey "FileDescription" "WinPython 3.12 Installation"
VIAddVersionKey "LegalCopyright" "Copyright © 2024"

RequestExecutionLevel admin

; Modern UI Configuration
!define MUI_ABORTWARNING
!define MUI_ICON "python.ico"
!define MUI_UNICON "python.ico"



; Pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
; Custom directory page that disables manual editing
!define MUI_PAGE_CUSTOMFUNCTION_PRE DirectoryPre
!define MUI_PAGE_CUSTOMFUNCTION_SHOW DirectoryShow

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Languages
!insertmacro MUI_LANGUAGE "English"

; Variable definitions
Var AddToPath
Var PythonDir
Var ProgressPosition
Var hDirectoryPage

; Installation sections
Section "WinPython 3.12 Core" SecCore
    SectionIn RO
    
    ; Set installation directory
    StrCpy $PythonDir "$INSTDIR"
    
    ; Create installation directory
    SetOutPath "$INSTDIR"
    
    ; Show progress
    DetailPrint "Extracting WinPython files..."
    StrCpy $ProgressPosition 0
    
    ; Extract main zip file
    File "WPy64-312101.7z"
    
    ; Update progress
    IntOp $ProgressPosition $ProgressPosition + 30
    Call UpdateProgress
    
    ; Use nsUnzip plugin to extract
    DetailPrint "Installing Python core..."
    Nsis7z::ExtractWithDetails "WPy64-312101.7z" "Extracting: %s" "$INSTDIR"
    
    ; Delete zip file
    Delete "$INSTDIR\WPy64-312101.7z"

    ; Update progress
    IntOp $ProgressPosition $ProgressPosition + 20
    Call UpdateProgress
    
    ; Set python directory variable
    StrCpy $PythonDir "$INSTDIR\python"
    
    ; Copy wheelhouse directory
    DetailPrint "Copying package files..."
    SetOutPath "$INSTDIR"
    File /r "wheelhouse"
    
    ; Update progress
    IntOp $ProgressPosition $ProgressPosition + 10
    Call UpdateProgress
    
    ; Install packages from wheelhouse
    DetailPrint "Installing Python packages..."
    
    ; Find all whl files in wheelhouse
    FindFirst $0 $1 "$INSTDIR\wheelhouse\*.whl"
    ${Do}
        StrCmp $1 "" done_whl
        DetailPrint "Installing: $1"
        nsExec::ExecToStack '"$PythonDir\python.exe" -m pip install "$INSTDIR\wheelhouse\$1" --no-index --find-links="$INSTDIR\wheelhouse" --quiet'
        Pop $2
        Pop $3
        ${If} $2 != 0
            DetailPrint "Failed to install $1: $3"
        ${Else}
            DetailPrint "Successfully installed: $1"
        ${EndIf}
        FindNext $0 $1
    ${Loop}
    done_whl:
    FindClose $0
    
    ; Update progress
    IntOp $ProgressPosition $ProgressPosition + 20
    Call UpdateProgress
    
    ; Install from requirements.txt if exists
    IfFileExists "$INSTDIR\wheelhouse\requirements.txt" 0 no_requirements
    DetailPrint "Installing packages from requirements.txt..."
    nsExec::ExecToStack '"$PythonDir\python.exe" -m pip install -r "$INSTDIR\wheelhouse\requirements.txt" --no-index --find-links="$INSTDIR\wheelhouse" --quiet'
    Pop $2
    Pop $3
    ${If} $2 != 0
        DetailPrint "Failed to install from requirements.txt: $3"
    ${Else}
        DetailPrint "Successfully installed packages from requirements.txt"
    ${EndIf}
    no_requirements:
    
    ; Update progress
    IntOp $ProgressPosition $ProgressPosition + 10
    Call UpdateProgress
    
    ; Write to registry
    DetailPrint "Writing registry entries..."
    WriteRegStr HKLM "SOFTWARE\TaiJiControl\PythonEnv" "InstallPath" "$PythonDir"
    WriteRegStr HKLM "SOFTWARE\TaiJiControl\PythonEnv" "PythonPath" "$PythonDir"
    WriteRegStr HKLM "SOFTWARE\TaiJiControl\PythonEnv" "RootPath" "$INSTDIR"
    WriteRegStr HKLM "SOFTWARE\TaiJiControl\PythonEnv" "Version" "3.12.10"
    
    ; Write uninstall information
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WinPython312" "DisplayName" "WinPython 3.12"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WinPython312" "UninstallString" '"$INSTDIR\uninstall.exe"'
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WinPython312" "InstallLocation" "$INSTDIR"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WinPython312" "DisplayVersion" "3.12.10"
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WinPython312" "Publisher" "WinPython"
    WriteRegDWORD HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WinPython312" "NoModify" 1
    WriteRegDWORD HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WinPython312" "NoRepair" 1
    
    ; Create uninstaller
    WriteUninstaller "$INSTDIR\uninstall.exe"
    
    ; Update progress to complete
    StrCpy $ProgressPosition 100
    Call UpdateProgress
    
SectionEnd

Section "Add to PATH Environment Variable" SecPath
    ; This section is for user to choose whether to add to PATH
    StrCpy $AddToPath 1
SectionEnd

; Function to disable directory edit box
Function DirectoryPre
    ; This function is called before the directory page is shown
FunctionEnd

Function DirectoryShow
    ; Get the handle to the directory page
    FindWindow $hDirectoryPage "#32770" "" $HWNDPARENT
    
    ; Disable the directory edit box (control ID 1019)
    GetDlgItem $0 $hDirectoryPage 1019
    EnableWindow $0 0  ; Disable the edit control
    
    ; Optional: Change the text color to indicate it's disabled
    ; SetCtlColors $0 0x808080 0xFFFFFF
FunctionEnd


; 这个section会在所有其他section之后执行
Section -PostInstall
    ; 如果用户选择添加到PATH
    ${If} $AddToPath == 1
        DetailPrint "Adding to system PATH environment variable..."
        
        ; Add to system PATH
        EnVar::SetHKLM
        EnVar::Check "Path" "$PythonDir"
        Pop $0
        ${If} $0 != 0
            EnVar::AddValue "Path" "$PythonDir"
            Pop $0
            ${If} $0 == 0
                DetailPrint "Added Python directory to system PATH environment variable"
            ${Else}
                DetailPrint "Failed to add Python directory to PATH: $0"
            ${EndIf}
        ${Else}
            DetailPrint "Python directory already in PATH environment variable"
        ${EndIf}
        
        ; Add Scripts directory to PATH
        EnVar::SetHKLM
        EnVar::Check "Path" "$PythonDir\Scripts"
        Pop $0
        ${If} $0 != 0
            EnVar::AddValue "Path" "$PythonDir\Scripts"
            Pop $0
            ${If} $0 == 0
                DetailPrint "Added Scripts directory to system PATH environment variable"
            ${Else}
                DetailPrint "Failed to add Scripts directory to PATH: $0"
            ${EndIf}
        ${Else}
            DetailPrint "Scripts directory already in PATH environment variable"
        ${EndIf}
    ${EndIf}
SectionEnd

Function UpdateProgress
    SetDetailsPrint both
    DetailPrint "Progress: $ProgressPosition% complete"
    SetDetailsPrint listonly
FunctionEnd

Function .onInit
    ; Initialize variables
    StrCpy $AddToPath 0
    StrCpy $ProgressPosition 0

    ; Set section selection state - uncheck "Add to PATH" by default
    SectionSetFlags ${SecPath} 0
    
    ; Check if already installed
    ReadRegStr $0 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WinPython312" "UninstallString"
    StrCmp $0 "" done
    
    MessageBox MB_YESNO|MB_ICONQUESTION "WinPython 3.12 is already installed. Would you like to uninstall the previous version?" IDYES uninst IDNO done
    
    uninst:
        ExecWait '$0 _?=$INSTDIR'
    
    done:
FunctionEnd

Function .onInstSuccess
    ; Show completion message
    ${If} $AddToPath == 1
        MessageBox MB_YESNO|MB_ICONINFORMATION "WinPython 3.12 installation completed!$\n$\nInstallation directory: $INSTDIR$\nPython directory: $PythonDir$\n$\nPython has been added to your system PATH.$\n$\nWould you like to open the installation directory?" IDYES openDir IDNO noOpen
    ${Else}
        MessageBox MB_YESNO|MB_ICONINFORMATION "WinPython 3.12 installation completed!$\n$\nInstallation directory: $INSTDIR$\nPython directory: $PythonDir$\n$\nWould you like to open the installation directory?" IDYES openDir IDNO noOpen
    ${EndIf}
    
    openDir:
        ExecShell "open" "$INSTDIR"
    noOpen:
FunctionEnd

Function .onSelChange
    ; Handle component selection change if needed
FunctionEnd

; Uninstall section
Section "Uninstall"
    
    ; Remove from PATH environment variable
    DetailPrint "Removing from PATH environment variable..."
    
    ; Remove Python directory from PATH
    EnVar::SetHKLM
    EnVar::Check "Path" "$INSTDIR\python"
    Pop $0
    ${If} $0 == 0
        EnVar::DeleteValue "Path" "$INSTDIR\python"
        Pop $0
        ${If} $0 == 0
            DetailPrint "Removed Python directory from PATH"
        ${Else}
            DetailPrint "Failed to remove Python directory from PATH: $0"
        ${EndIf}
    ${EndIf}
    
    ; Remove Scripts directory from PATH
    EnVar::SetHKLM
    EnVar::Check "Path" "$INSTDIR\python\Scripts"
    Pop $0
    ${If} $0 == 0
        EnVar::DeleteValue "Path" "$INSTDIR\python\Scripts"
        Pop $0
        ${If} $0 == 0
            DetailPrint "Removed Scripts directory from PATH"
        ${Else}
            DetailPrint "Failed to remove Scripts directory from PATH: $0"
        ${EndIf}
    ${EndIf}
    
    ; Delete registry keys
    DetailPrint "Removing registry entries..."
    DeleteRegKey HKLM "SOFTWARE\TaiJiControl\PythonEnv"
    DeleteRegKey HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WinPython312"
    
    ; Delete installation directory
    DetailPrint "Removing installation files..."
    RMDir /r "$INSTDIR"
    
    MessageBox MB_OK|MB_ICONINFORMATION "WinPython 3.12 has been successfully uninstalled from your computer."
SectionEnd

; Section descriptions
LangString DESC_SecCore ${LANG_ENGLISH} "Core WinPython 3.12 files including Python interpreter and standard library."
LangString DESC_SecPath ${LANG_ENGLISH} "Add Python and Scripts directories to system PATH environment variable for easy command line access."

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecCore} $(DESC_SecCore)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecPath} $(DESC_SecPath)
!insertmacro MUI_FUNCTION_DESCRIPTION_END