object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'DotEnv DevTool'
  ClientHeight = 717
  ClientWidth = 1455
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  WindowState = wsMaximized
  OnCreate = FormCreate
  TextHeight = 15
  object Splitter1: TSplitter
    Left = 556
    Top = 0
    Width = 4
    Height = 640
    Align = alRight
    ExplicitLeft = 584
    ExplicitHeight = 629
  end
  object memLog: TMemo
    Left = 0
    Top = 640
    Width = 1455
    Height = 77
    Align = alBottom
    ScrollBars = ssBoth
    TabOrder = 0
  end
  object panContents: TPanel
    Left = 0
    Top = 0
    Width = 556
    Height = 640
    Align = alClient
    AutoSize = True
    Constraints.MinWidth = 100
    TabOrder = 1
    object labContentsHeader: TLabel
      Left = 1
      Top = 1
      Width = 554
      Height = 15
      Align = alTop
      Alignment = taCenter
      Caption = 'DotEnv File Contents'
      Layout = tlCenter
      ExplicitWidth = 110
    end
    object memDotEnvContents: TMemo
      Left = 1
      Top = 16
      Width = 554
      Height = 582
      Align = alClient
      ScrollBars = ssBoth
      TabOrder = 0
    end
    object panContentsActions: TPanel
      Left = 1
      Top = 598
      Width = 554
      Height = 41
      Align = alBottom
      TabOrder = 1
      object butSaveContents: TButton
        Left = 16
        Top = 6
        Width = 145
        Height = 25
        Caption = 'Save and Reload .env'
        TabOrder = 0
        OnClick = butSaveContentsClick
      end
    end
  end
  object panGrids: TPanel
    Left = 560
    Top = 0
    Width = 895
    Height = 640
    Align = alRight
    Constraints.MinWidth = 400
    TabOrder = 2
    object Splitter2: TSplitter
      Left = 442
      Top = 1
      Width = 4
      Height = 638
      ExplicitLeft = 297
      ExplicitHeight = 627
    end
    object panParsed: TPanel
      Left = 1
      Top = 1
      Width = 441
      Height = 638
      Align = alLeft
      Caption = 'panParsed'
      TabOrder = 0
      object labParsedHeader: TLabel
        Left = 1
        Top = 1
        Width = 439
        Height = 15
        Align = alTop
        Alignment = taCenter
        Caption = 'DotEnv Parsed Key Values'
        Layout = tlCenter
        ExplicitWidth = 134
      end
      object gridDotEnvParsed: TStringGrid
        Left = 1
        Top = 16
        Width = 439
        Height = 621
        Align = alClient
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        TabOrder = 0
      end
    end
    object panSys: TPanel
      Left = 446
      Top = 1
      Width = 448
      Height = 638
      Align = alClient
      TabOrder = 1
      object labSysHeader: TLabel
        Left = 1
        Top = 1
        Width = 446
        Height = 15
        Align = alTop
        Alignment = taCenter
        Caption = 'Current System Environment Variables'
        Layout = tlCenter
        ExplicitWidth = 201
      end
      object gridSys: TStringGrid
        Left = 1
        Top = 16
        Width = 446
        Height = 621
        Align = alClient
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        TabOrder = 0
      end
    end
  end
end
