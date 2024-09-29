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


; These are required (from Preferences.pb)
Global PreferenceToolsPanelFrontColor, PreferenceToolsPanelBackColor
Declare UpdatePreferenceSyntaxColor(ColorIndex, Color)
Declare UpdateImageColorGadget(Gadget, Image, Color)


Procedure.i ColorSchemeMatchesCurrentSettings(*ColorScheme.ColorSchemeStruct)
  Protected Result.i = #True
  
  For i = 0 To #COLOR_Last
    If ((i <> #COLOR_Selection) And (i <> #COLOR_SelectionFront)) ; selection colors may follow OS, so skip them for scheme match check
      If (Colors(i)\Enabled And (*ColorScheme\ColorValue[i] >= 0))
        If (*ColorScheme\ColorValue[i] <> Colors(i)\UserValue)
          Result = #False
          Break
        EndIf
      EndIf
    EndIf
  Next i
  
  ProcedureReturn (Result)
EndProcedure

Procedure ApplyColorSchemeToIDE(*ColorScheme.ColorSchemeStruct)
  If (*ColorScheme)
    
    ; Placeholder for future functionality: immediately apply a color scheme to IDE without using Preferences window
    
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
      If *ColorScheme\IsIDEDefault Or *ColorScheme\IsAccessibility
        Colors(#COLOR_Selection)\PrefsValue      = GetSysColor_(#COLOR_HIGHLIGHT)
        Colors(#COLOR_SelectionFront)\PrefsValue = GetSysColor_(#COLOR_HIGHLIGHTTEXT)
      EndIf
    CompilerEndIf
    
    For i = 0 To #COLOR_Last
      If (Colors(i)\PrefsValue <> -1)
        Color = Colors(i)\PrefsValue
        DisableGadget(#GADGET_Preferences_FirstColorText+i, 0)
        DisableGadget(#GADGET_Preferences_FirstSelectColor+i, 0)
      Else
        If ((i <> #COLOR_GlobalBackground) And (FindString(ColorName(i), "Back") > 0))
          Color = *ColorScheme\ColorValue[#COLOR_GlobalBackground] ; assume it should match global background
        ElseIf ((i <> #COLOR_NormalText) And (FindString(ColorName(i), "Back") = 0))
          Color = *ColorScheme\ColorValue[#COLOR_NormalText] ; assume it should match normal foreground color
        Else
          Color = $C0C0C0
        EndIf
        DisableGadget(#GADGET_Preferences_FirstColorText+i, 1)
        DisableGadget(#GADGET_Preferences_FirstSelectColor+i, 1)
      EndIf
      
      UpdatePreferenceSyntaxColor(i, Color)
    Next i
    
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
          Else ; NULL --> dynamically allocate a struct now - NOT part of InitColorSchemes() list!
            *ColorScheme = AllocateStructure(ColorSchemeStruct)
          EndIf
          
          If (*ColorScheme)
            With *ColorScheme
              \Name = Name
              \File = File
              
              ; Load all defined colors into map...
              For i = 0 To #COLOR_Last_IncludingToolsPanel
                \ColorValue[i] = -1
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
              Result = *ColorScheme
              
            EndWith
          EndIf
          
        EndIf
      EndIf
      ClosePreferences()
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
