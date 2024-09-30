; --------------------------------------------------------------------------------------------
;  Copyright (c) Fantaisie Software. All rights reserved.
;  Dual licensed under the GPL and Fantaisie Software licenses.
;  See LICENSE and LICENSE-FANTAISIE in the project root for license information.
; --------------------------------------------------------------------------------------------

#COLOR_Last_IncludingToolsPanel = #COLOR_Last + 2

Global Dim ColorName.s(#COLOR_Last_IncludingToolsPanel)

Structure ColorSchemeStruct
  Name.s
  File.s
  
  ColorValue.l[#COLOR_Last_IncludingToolsPanel + 1]
  
  IsIDEDefault.i
  IsAccessibility.i
EndStructure

Global NewList ColorScheme.ColorSchemeStruct()

#ColorSchemeValue_UseSysColor = -1
#ColorSchemeValue_Undefined   = -2


; These are required (from Preferences.pb)
Global PreferenceToolsPanelFrontColor, PreferenceToolsPanelBackColor
Declare UpdatePreferenceSyntaxColor(ColorIndex, Color)
Declare UpdateImageColorGadget(Gadget, Image, Color)
Declare ApplyAllColorPreferences()


Procedure.i ColorSchemeMatchesCurrentSettings(*ColorScheme.ColorSchemeStruct)
  Protected Result.i = #True
  
  For i = 0 To #COLOR_Last
    If ((i <> #COLOR_Selection) And (i <> #COLOR_SelectionFront)) ; selection colors may follow OS, so skip them for scheme match check
      If (*ColorScheme\ColorValue[i] >= 0)
        If (*ColorScheme\ColorValue[i] <> Colors(i)\UserValue)
          Result = #False
          Break
        EndIf
      EndIf
    EndIf
  Next i
  
  ProcedureReturn (Result)
EndProcedure

Procedure.i FindCurrentColorScheme()
  Protected *ColorScheme.ColorSchemeStruct = #Null
  
  ForEach ColorScheme()
    If (ColorSchemeMatchesCurrentSettings(@ColorScheme()))
      *ColorScheme = @ColorScheme()
      Break
    EndIf
  Next
  
  ProcedureReturn (*ColorScheme)
EndProcedure

Procedure.i IsRequiredColorSchemeColor(index.i)
  Select (index)
    ; In Preferences window, these colors do not have a checkbox to disable them
    Case #COLOR_NormalText, #COLOR_GlobalBackground, #COLOR_PlainBackground, #COLOR_Cursor, #COLOR_Selection, #COLOR_SelectionFront
      ProcedureReturn (#True)
    Case #COLOR_ToolsPanelFrontColor, #COLOR_ToolsPanelBackColor
      ProcedureReturn (#True)
  EndSelect
  ProcedureReturn (#False)
EndProcedure

Procedure.i GuessColorSchemeColor(*ColorScheme.ColorSchemeStruct, index.i)
  Select (index)
    Case #COLOR_GlobalBackground
      Color = #White
    Case #COLOR_NormalText
      Color = $FFFFFF - *ColorScheme\ColorValue[#COLOR_GlobalBackground]
      
    Case #COLOR_CurrentLine, #COLOR_DisabledBack, #COLOR_LineNumberBack, #COLOR_PlainBackground, #COLOR_ProcedureBack, #COLOR_ToolsPanelBackColor
      Color = *ColorScheme\ColorValue[#COLOR_GlobalBackground] ; assume it should match global background
    Case #COLOR_DebuggerBreakPoint, #COLOR_DebuggerError, #COLOR_DebuggerLine, #COLOR_DebuggerWarning
      Color = *ColorScheme\ColorValue[#COLOR_GlobalBackground]
      
    Case #COLOR_SelectionFront
      CompilerIf (#CompileWindows)
        Color = GetSysColor_(#COLOR_HIGHLIGHTTEXT)
      CompilerElse
        Color = *ColorScheme\ColorValue[#COLOR_GlobalBackground]
      CompilerEndIf
    Case #COLOR_Selection, #COLOR_SelectionRepeat
      CompilerIf (#CompileWindows)
        Color = GetSysColor_(#COLOR_HIGHLIGHT)
      CompilerElse
        Color = *ColorScheme\ColorValue[#COLOR_NormalText]
      CompilerEndIf
      
    Default
      Color = *ColorScheme\ColorValue[#COLOR_NormalText] ; otherwise, assume it should match normal foreground color
  EndSelect
  
  ProcedureReturn (Color)
EndProcedure

Procedure DisableSelectionColorGadgets(*ColorScheme.ColorSchemeStruct)
  CompilerIf #CompileWindows
    ShouldDisable = #False
    
    If (EnableAccessibility)
      ShouldDisable = #True ; Accessibility mode enabled - use system selection colors, don't allow user to change them
    Else
      If (*ColorScheme)
        If (*ColorScheme\IsAccessibility)
          ShouldDisable = #True ; Accessibility scheme selected - use system selection colors, don't allow user to change them
        ElseIf (*ColorScheme\ColorValue[#COLOR_Selection] = #ColorSchemeValue_UseSysColor) Or (*ColorScheme\ColorValue[#COLOR_SelectionFront] = #ColorSchemeValue_UseSysColor)
          ShouldDisable = #True ;; Value of -1 (use system color) specified
        EndIf
      EndIf
    EndIf
    
    DisableGadget(#GADGET_Preferences_FirstColorText   + #COLOR_Selection,      ShouldDisable)
    DisableGadget(#GADGET_Preferences_FirstSelectColor + #COLOR_Selection,      ShouldDisable)
    DisableGadget(#GADGET_Preferences_FirstColorText   + #COLOR_SelectionFront, ShouldDisable)
    DisableGadget(#GADGET_Preferences_FirstSelectColor + #COLOR_SelectionFront, ShouldDisable)
  CompilerEndIf
EndProcedure

Procedure ApplyColorSchemeToIDE(*ColorScheme.ColorSchemeStruct)
  If (*ColorScheme)
    
    For i = 0 To #COLOR_Last
      Colors(i)\UserValue = *ColorScheme\ColorValue[i]
      If (*ColorScheme\ColorValue[i] >= 0)
        Colors(i)\Enabled = #True
      Else
        Colors(i)\UserValue = GuessColorSchemeColor(*ColorScheme, i)
        If (IsRequiredColorSchemeColor(i))
          Colors(i)\Enabled = #True
        EndIf
      EndIf
    Next i
    
    CompilerIf #CompileWindows
      If *ColorScheme\IsIDEDefault Or *ColorScheme\IsAccessibility Or EnableAccessibility
        Colors(#COLOR_Selection)\UserValue      = GetSysColor_(#COLOR_HIGHLIGHT)
        Colors(#COLOR_SelectionFront)\UserValue = GetSysColor_(#COLOR_HIGHLIGHTTEXT)
      EndIf
    CompilerEndIf
    
    ToolsPanelFrontColor = *ColorScheme\ColorValue[#COLOR_ToolsPanelFrontColor]
    If (ToolsPanelFrontColor < 0)
      ToolsPanelFrontColor = GuessColorSchemeColor(*ColorScheme, #COLOR_ToolsPanelFrontColor)
    EndIf
    ToolsPanelBackColor  = *ColorScheme\ColorValue[#COLOR_ToolsPanelBackColor]
    If (ToolsPanelBackColor < 0)
      ToolsPanelBackColor = GuessColorSchemeColor(*ColorScheme, #COLOR_ToolsPanelBackColor)
    EndIf
    
    ApplyAllColorPreferences()
  
  EndIf
EndProcedure

Procedure LoadColorSchemeToPreferencesWindow(*ColorScheme.ColorSchemeStruct)
  If (*ColorScheme)
    
    PreferenceToolsPanelFrontColor = *ColorScheme\ColorValue[#COLOR_ToolsPanelFrontColor]
    PreferenceToolsPanelBackColor  = *ColorScheme\ColorValue[#COLOR_ToolsPanelBackColor]
    
    For i = 0 To #COLOR_Last
      Colors(i)\PrefsValue = *ColorScheme\ColorValue[i]
    Next i
    
    CompilerIf #CompileWindows
      ; Special thing: On windows we always default back to the system colors in
      ; the PB standard scheme for screenreader support. The 'Accessibility'
      ; scheme has a special option to always use these colors, so it is not needed here.
      ;
      If *ColorScheme\IsIDEDefault Or *ColorScheme\IsAccessibility Or EnableAccessibility Or (Colors(#COLOR_Selection)\PrefsValue = #ColorSchemeValue_UseSysColor)
        Colors(#COLOR_Selection)\PrefsValue      = GetSysColor_(#COLOR_HIGHLIGHT)
        Colors(#COLOR_SelectionFront)\PrefsValue = GetSysColor_(#COLOR_HIGHLIGHTTEXT)
      EndIf
    CompilerEndIf
    
    For i = 0 To #COLOR_Last
      If (Colors(i)\PrefsValue >= 0)
        UpdatePreferenceSyntaxColor(i, Colors(i)\PrefsValue)
      Else
        Colors(i)\PrefsValue = GuessColorSchemeColor(*ColorScheme, i)
        UpdatePreferenceSyntaxColor(i, Colors(i)\PrefsValue)
      EndIf
    Next i
    
    DisableSelectionColorGadgets(*ColorScheme)
    
    If (PreferenceToolsPanelFrontColor < 0)
      PreferenceToolsPanelFrontColor = GuessColorSchemeColor(*ColorScheme, #COLOR_ToolsPanelFrontColor)
    EndIf
    If (PreferenceToolsPanelBackColor < 0)
      PreferenceToolsPanelBackColor = GuessColorSchemeColor(*ColorScheme, #COLOR_ToolsPanelBackColor)
    EndIf
    
    If IsImage(#IMAGE_Preferences_ToolsPanelFrontColor)
      UpdateImageColorGadget(#GADGET_Preferences_ToolsPanelFrontColor, #IMAGE_Preferences_ToolsPanelFrontColor, PreferenceToolsPanelFrontColor)
    EndIf
    If IsImage(#IMAGE_Preferences_ToolsPanelBackColor)
      UpdateImageColorGadget(#GADGET_Preferences_ToolsPanelBackColor, #IMAGE_Preferences_ToolsPanelBackColor, PreferenceToolsPanelBackColor)
    EndIf
    
  EndIf
EndProcedure

Procedure RemoveColorSchemeIfExists(Name.s)
  If (Name <> "")
    ForEach ColorScheme()
      If (ColorScheme()\Name = Name)
        DeleteElement(ColorScheme())
        Break
      EndIf
    Next
  EndIf
EndProcedure

Procedure.i ReadColorSchemeFromDataSection(*ColorScheme.ColorSchemeStruct)
  If (*ColorScheme)
    ; This assumes the NAME STRING data has already been read!
    With *ColorScheme
      \File = ""
      Read.l \ColorValue[#COLOR_ToolsPanelFrontColor]
      Read.l \ColorValue[#COLOR_ToolsPanelBackColor]
      For i = 0 To #COLOR_Last
        Read.l \ColorValue[i]
      Next i
    EndWith
  EndIf
  
  ProcedureReturn (*ColorScheme)
EndProcedure

Procedure.i LoadColorSchemeFromFile(*ColorScheme.ColorSchemeStruct, File.s)
  Protected Result.i = #Null
  
  If (File)
    ; Basic validation of color scheme file...
    If (OpenPreferences(File))
      Name.s = GetFilePart(File, #PB_FileSystem_NoExtension)
      If (#True);(PreferenceGroup("Sections") And (ReadPreferenceLong("IncludeColors", 0) = 1))
        If (PreferenceGroup("Colors"))
          
          If (*ColorScheme) ; struct already specified - part of InitColorSchemes() list
            ; Intentionally overwrite schemes of existing names - allows you to tweak the default themes, if desired
            RemoveColorSchemeIfExists(Name)
            Allocated.i = #False
          Else ; NULL --> dynamically allocate a struct now - NOT part of InitColorSchemes() list!
            *ColorScheme = AllocateStructure(ColorSchemeStruct)
            Allocated.i = #True
          EndIf
          
          If (*ColorScheme)
            With *ColorScheme
              \Name = Name
              \File = File
              
              ; Load all defined colors into map...
              For i = 0 To #COLOR_Last_IncludingToolsPanel
                \ColorValue[i] = #ColorSchemeValue_Undefined
                ColorValueString.s = ReadPreferenceString(ColorName(i), "")
                If (ColorValueString <> "")
                  If (ReadPreferenceLong(ColorName(i) + "_Used", 1) = 1)
                    If (FindString(ColorValueString, "RGB", 1, #PB_String_NoCase))
                      \ColorValue[i] = ColorFromRGBString(ColorValueString)
                    Else
                      \ColorValue[i] = Val(ColorValueString) & $00FFFFFF
                    EndIf
                  EndIf
                EndIf
              Next i
              
              ; Require at least background and text colors to be defined, or else reject it
              If ((\ColorValue[#COLOR_GlobalBackground] >= 0) And (\ColorValue[#COLOR_NormalText] >= 0))
                Result = *ColorScheme
                
                ; Fill in missing colors
                For i = 0 To #COLOR_Last_IncludingToolsPanel
                  If (#True);(IsRequiredColorSchemeColor(i))
                    If (\ColorValue[i] = -1)
                      \ColorValue[i] = GuessColorSchemeColor(*ColorScheme, i)
                    EndIf
                  EndIf
                Next i
              EndIf
              
            EndWith
            If (Not Result)
              If (Allocated)
                FreeStructure(*ColorScheme)
              EndIf
            EndIf
          EndIf
          
        EndIf
      EndIf
      ClosePreferences()
    EndIf
  EndIf
  
  ProcedureReturn (Result)
EndProcedure

Procedure.i ColorSchemeByName(Name.s)
  Protected *ColorScheme.ColorSchemeStruct = #Null
  
  ForEach (ColorScheme())
    If ((ColorScheme()\Name = Name) Or (#CompileWindows And (LCase(ColorScheme()\Name) = LCase(Name))))
      *ColorScheme = @ColorScheme()
      Break
    EndIf
  Next
  
  ProcedureReturn (*ColorScheme)
EndProcedure

Procedure.i ApplyColorSchemeResourceToIDE(Resource.s)
  Protected Result.i = #False
  
  If IsWindow(#WINDOW_Preferences)
    ProcedureReturn (#False)
  EndIf
  
  If (Resource)
    
    Protected *ColorScheme.ColorSchemeStruct = ColorSchemeByName(Resource)
    If (*ColorScheme)
      ApplyColorSchemeToIDE(*ColorScheme)
    Else
      Protected TempColorScheme.ColorSchemeStruct
      If (LoadColorSchemeFromFile(@TempColorScheme, Resource))
        ApplyColorSchemeToIDE(@TempColorScheme)
      Else
        MessageRequester(#ProductName$, Language("FileStuff","MiscLoadError")+#NewLine+Resource, #FLAG_Error)
        ChangeStatus(Language("FileStuff","MiscLoadError"), 3000)
      EndIf
    EndIf
    
  EndIf
  
  ProcedureReturn (Result)
EndProcedure

Procedure InitColorSchemes()
  
  ;ClearDebugOutput()
  ;Debug #PB_Compiler_Procedure + "()"
  
  ; Only need to initialize color schemes once
  If (NbSchemes > 0)
    ProcedureReturn
  EndIf
  
  ; Read color key names into indexable array
  Restore ColorKeys
  For i = 0 To #COLOR_Last
    Read.s ColorName(i)
  Next i
  ColorName(#COLOR_ToolsPanelFrontColor) = "ToolsPanel_FrontColor"
  ColorName(#COLOR_ToolsPanelBackColor)  = "ToolsPanel_BackColor"
  
  
  ; First, load embedded DataSection default color schemes
  ClearList(ColorScheme())
  Restore DefaultColorSchemes
  Read.s Name.s
  While (Name <> "")
    AddElement(ColorScheme())
    ColorScheme()\Name = Name
    ReadColorSchemeFromDataSection(@ColorScheme())
    If (ListIndex(ColorScheme()) = 0)
      ColorScheme()\IsIDEDefault = #True
    EndIf
    Read.s Name
  Wend
  NbSchemes = ListSize(ColorScheme())
  
  ; Then, scan 'themes' subfolder!
  If (PureBasicPath$)
    Dir = ExamineDirectory(#PB_Any, PureBasicPath$ + "themes", "*.prefs")
    If (Dir)
      While (NextDirectoryEntry(Dir))
        File.s = PureBasicPath$ + "themes" + #PS$ + DirectoryEntryName(Dir)
        AddElement(ColorScheme())
        If (LoadColorSchemeFromFile(@ColorScheme(), File))
          ; OK
        Else
          DeleteElement(ColorScheme())
        EndIf
      Wend
      FinishDirectory(Dir)
    EndIf
  EndIf
  
  
  ; If additional schemes were found, sort schemes alphabetically, because it could become a long list
  If (ListSize(ColorScheme()) > NbSchemes)
    NbSchemes = ListSize(ColorScheme())
    SortStructuredList(ColorScheme(), #PB_Sort_Ascending | #PB_Sort_NoCase, OffsetOf(ColorSchemeStruct\Name), #PB_String)
  EndIf
  
  ; Ensure "Accessibility" scheme always at bottom of list, for special handling
  ForEach ColorScheme()
    If (ColorScheme()\Name = "Accessibility")
      ColorScheme()\IsAccessibility = #True
      MoveElement(ColorScheme(), #PB_List_Last)
    EndIf
  Next
  
  ;ForEach ColorScheme()
  ;  Debug ColorScheme()\Name
  ;Next
  
  ;CallDebugger
  
EndProcedure
