program install_paths;

uses
  System.StartUpCopy,
  FMX.Forms,
  UMain in 'UMain.pas' {MainForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
