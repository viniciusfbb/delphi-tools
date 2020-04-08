unit UMain;

interface

uses
  Winapi.Windows, System.Win.Registry, System.IniFiles,
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.ScrollBox, FMX.Memo, FMX.Controls.Presentation, FMX.Layouts;

const
  MIN_BDS_VERSION = 19;
  MAX_BDS_VERSION = 20;

type
  TMainForm = class(TForm)
    lblLibraryPath: TLabel;
    memLibraryPath: TMemo;
    lblBrowsingPath: TLabel;
    memBrowsingPath: TMemo;
    lblDebugPath: TLabel;
    memDebugPath: TMemo;
    btnInstall: TButton;
    StyleBook: TStyleBook;
    lytBottom: TLayout;
    Label1: TLabel;
    procedure btnInstallClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

uses
  System.IOUtils;

{$R *.fmx}

procedure TMainForm.btnInstallClick(Sender: TObject);

  procedure AddPaths(AReg: TRegistry; const AKeyPath, ARegName: string; AStrings: TStrings);
  const
    ALL_PLATFORMS: array[0..8] of string = ('Win32', 'Win64', 'iOSDevice32', 'iOSDevice64', 'iOSSimulator', 'OSX32', 'Android32', 'Android64', 'Linux64');
    ALL_PLATFORMS_PATH_NAMES: array[0..8] of string = ('Win32', 'Win64', 'iOSDevice32', 'iOSDevice64', 'iOSSimulator', 'OSX32', 'Android', 'Android64', 'Linux64');
  var
    LPlatform: string;
    LPlatformPath: string;
    LList: TStringList;
    LDir: string;
    LFullDir: string;
    LListItem: string;
    I: Integer;
    J: Integer;
    K: Integer;
  begin
    for K := Low(ALL_PLATFORMS) to High(ALL_PLATFORMS) do
    begin
      LPlatform := ALL_PLATFORMS[K];
      LPlatformPath := AKeyPath + LPlatform + '\';
      if AReg.KeyExists(LPlatformPath) then
      begin
        AReg.OpenKey(LPlatformPath, False);
        try
          LList := TStringList.Create;
          try
            LList.Text := AReg.ReadString(ARegName).Replace(';', #13#10, [rfReplaceAll]).Trim;
            for I := 0 to AStrings.Count-1 do
            begin
              LDir := TPath.GetFullPath(AStrings[I]);
              LFullDir := LDir.Replace('($Platform)', ALL_PLATFORMS_PATH_NAMES[K], [rfReplaceAll, rfIgnoreCase]);
              for J := LList.Count-1 downto I do
              begin
                LListItem := LList[J].ToLower.Trim;
                if LListItem.EndsWith('\') then
                  LListItem := LListItem.Substring(0, LListItem.Length-1);
                if (LDir.ToLower = LListItem) or (LFullDir.ToLower = LListItem) then
                  LList.Delete(J);
              end;
              LList.Insert(I, LFullDir);
            end;
            AReg.WriteString(ARegName, LList.Text.Replace(#13#10, ';', [rfReplaceAll]).Trim);
          finally
            LList.Free;
          end;
        finally
          AReg.CloseKey;
        end;
      end;
    end;
  end;

  procedure ClearInvalidStrings(AStrings: TStrings);
  var
    I: Integer;
    J: Integer;
    LStr: string;
  begin
    // Fix the paths
    for I := AStrings.Count-1 downto 0 do
    begin
      AStrings[I] := AStrings[I].Trim;
      if AStrings[I].IsEmpty then
        AStrings.Delete(I)
      else if AStrings[I].EndsWith('\') then
        AStrings[I] := AStrings[I].Substring(0, AStrings[I].Length-1);
    end;
    // Remove invalid paths
    for I := AStrings.Count-1 downto 0 do
    begin
      try
        LStr := TPath.GetFullPath(AStrings[I]);
      except
        showmessage('Invalid path "'+AStrings[I]+'". It will be removed.');
        AStrings.Delete(I);
        Continue;
      end;
    end;
    // Remove duplicates
    for I := AStrings.Count-1 downto 0 do
    begin
      LStr := TPath.GetFullPath(AStrings[I]).ToLower;
      for J := 0 to I-1 do
      begin
        if TPath.GetFullPath(AStrings[J]).ToLower = LStr then
        begin
          AStrings.Delete(I);
          Break;
        end;
      end;
    end;
  end;

  procedure WriteIniStrings(AIni: TIniFile; AStrings: TStrings; const ASection: string);
  var
    I: Integer;
  begin
    for I := 0 to AStrings.Count-1 do
      AIni.WriteString(ASection, I.ToString, AStrings[I]);
  end;

var
  LReg: TRegistry;
  LKeyPath: string;
  LVersion: Integer;
  LIni: TIniFile;
begin
  ClearInvalidStrings(memLibraryPath.Lines);
  ClearInvalidStrings(memBrowsingPath.Lines);
  ClearInvalidStrings(memDebugPath.Lines);

  LReg := TRegistry.Create(KEY_ALL_ACCESS);
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    for LVersion := MIN_BDS_VERSION to MAX_BDS_VERSION do
    begin
      LKeyPath := Format('Software\Embarcadero\BDS\%d.0\Library\', [LVersion]);
      if LReg.KeyExists(LKeyPath) then
      begin
        AddPaths(LReg, LKeyPath, 'Search Path', memLibraryPath.Lines);
        AddPaths(LReg, LKeyPath, 'Browsing Path', memBrowsingPath.Lines);
        AddPaths(LReg, LKeyPath, 'Debug DCU Path', memDebugPath.Lines);
      end;
    end;
  finally
    LReg.Free;
  end;

  if TFile.Exists(TPath.ChangeExtension(ParamStr(0), '.ini')) then
    TFile.Delete(TPath.ChangeExtension(ParamStr(0), '.ini'));
  LIni := TIniFile.Create(TPath.ChangeExtension(ParamStr(0), '.ini'));
  try
    WriteIniStrings(LIni, memLibraryPath.Lines, 'Library Path');
    WriteIniStrings(LIni, memBrowsingPath.Lines, 'Browsing Path');
    WriteIniStrings(LIni, memDebugPath.Lines, 'Debug DCU Path');
  finally
    LIni.Free;
  end;

  Showmessage('Finished!');
end;

procedure TMainForm.FormCreate(Sender: TObject);

  procedure ReadIniStrings(AIni: TIniFile; AStrings: TStrings; const ASection: string);
  var
    I: Integer;
  begin
    I := 0;
    while AIni.ValueExists(ASection, I.ToString) do
    begin
      if AIni.ReadString(ASection, I.ToString, '') <> '' then
        AStrings.Add(AIni.ReadString(ASection, I.ToString, ''));
      Inc(I);
    end;
  end;

var
  LIni: TIniFile;
begin
  if TFile.Exists(TPath.ChangeExtension(ParamStr(0), '.ini')) then
  begin
    LIni := TIniFile.Create(TPath.ChangeExtension(ParamStr(0), '.ini'));
    try
      ReadIniStrings(LIni, memLibraryPath.Lines, 'Library Path');
      ReadIniStrings(LIni, memBrowsingPath.Lines, 'Browsing Path');
      ReadIniStrings(LIni, memDebugPath.Lines, 'Debug DCU Path');
    finally
      LIni.Free;
    end;
  end;
end;

end.
