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
EndStructure

Global NewList ColorScheme.ColorSchemeStruct()

#ColorSchemeValue_NotUsed = -1

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
      Read.l \ColorValue[#COLOR_Last + 1]
      Read.l \ColorValue[#COLOR_Last + 2]
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
          Else ; dynamically allocate a struct - NOT part of InitColorSchemes() list!
            *ColorScheme = AllocateStructure(ColorSchemeStruct)
          EndIf
          
          If (*ColorScheme)
            With *ColorScheme
              \Name = Name
              \File = File
              
              ; Load all defined colors into map...
              For i = 0 To #COLOR_Last_IncludingToolsPanel
                \ColorValue[i] = #ColorSchemeValue_NotUsed
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
  ColorName(#COLOR_Last + 1) = "ToolsPanel_FrontColor"
  ColorName(#COLOR_Last + 2) = "ToolsPanel_BackColor"
  
  
  ; First, load embedded DataSection default color schemes
  ClearList(ColorScheme())
  Restore DefaultColorSchemes
  Read.s Name.s
  While (Name <> "")
    AddElement(ColorScheme())
    ColorScheme()\Name = Name
    ReadColorSchemeFromDataSection(@ColorScheme())
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
      MoveElement(ColorScheme(), #PB_List_Last)
    EndIf
  Next
  
  ;ForEach ColorScheme()
  ;  Debug ColorScheme()\Name
  ;Next
  
  ;CallDebugger
  
EndProcedure
