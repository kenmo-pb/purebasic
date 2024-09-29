; --------------------------------------------------------------------------------------------
;  Copyright (c) Fantaisie Software. All rights reserved.
;  Dual licensed under the GPL and Fantaisie Software licenses.
;  See LICENSE and LICENSE-FANTAISIE in the project root for license information.
; --------------------------------------------------------------------------------------------

Structure ColorSchemeStruct
  Name.s
  File.s
  Map ColorValue.i()
EndStructure

Global NewList ColorScheme.ColorSchemeStruct()

#COLOR_Last_WithToolsPanel = #COLOR_Last + 2

Global Dim ColorName.s(#COLOR_Last_WithToolsPanel)

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

Procedure InitColorSchemes()
  
  ;ClearDebugOutput()
  ;Debug #PB_Compiler_Procedure + "()"
  
  ; Read color names into indexable array
  Global Dim ColorName.s(#COLOR_Last + 2)
  Restore ColorKeys
  For i = 0 To #COLOR_Last
    Read.s ColorName(i)
  Next i
  ColorName(#COLOR_Last + 1) = "ToolsPanel_FrontColor"
  ColorName(#COLOR_Last + 2) = "ToolsPanel_BackColor"
  
  
  ; First, load embedded default color schemes
  ClearList(ColorScheme())
  Restore DefaultColorSchemes
  Read.s Name.s
  While (Name <> "")
    AddElement(ColorScheme())
    With ColorScheme()
      \Name = Name
      ;Debug Name
      Read.l \ColorValue(ColorName(#COLOR_Last + 1))
      Read.l \ColorValue(ColorName(#COLOR_Last + 2))
      For i = 0 To #COLOR_Last
        Read.l \ColorValue(ColorName(i))
        ;Debug ColorName(i) + " = " + Hex(\ColorValue(ColorName(i)))
      Next i
      ;Debug ""
    EndWith
    Read.s Name
  Wend
  NbSchemes = ListSize(ColorScheme())
  
  ; Then, scan 'themes' subfolder!
  If (PureBasicPath$)
    Dir = ExamineDirectory(#PB_Any, PureBasicPath$ + "themes", "*.prefs")
    If (Dir)
      While (NextDirectoryEntry(Dir))
        File.s = PureBasicPath$ + "themes" + #PS$ + DirectoryEntryName(Dir)
        
        ; Basic validation of color scheme file...
        If (OpenPreferences(File))
          If (#True);(PreferenceGroup("Sections") And (ReadPreferenceLong("IncludeColors", 0) = 1))
            If (PreferenceGroup("Colors"))
              Name = GetFilePart(File, #PB_FileSystem_NoExtension)
              
              ; Intentionally overwrite schemes of existing names - allows you to customize the default themes, if desired
              RemoveColorSchemeIfExists(Name)
              AddElement(ColorScheme())
              With ColorScheme()
                \Name = Name
                \File = File
                
                ; Load all defined colors into map...
                For i = 0 To #COLOR_Last_WithToolsPanel
                  If (ReadPreferenceLong(ColorName(i) + "_Used", 1) = 1)
                    ColorValueString.s = ReadPreferenceString(ColorName(i), "")
                    If (ColorValueString <> "")
                      If (FindString(ColorValueString, "RGB", 1, #PB_String_NoCase))
                        \ColorValue(ColorName(i)) = ColorFromRGBString(ColorValueString)
                      Else
                        \ColorValue(ColorName(i)) = Val(ColorValueString)
                      EndIf
                    EndIf
                  EndIf
                Next i
                
              EndWith
            EndIf
          EndIf
          ClosePreferences()
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
  
  ForEach ColorScheme()
    Debug ColorScheme()\Name
  Next
  
  CallDebugger
  
EndProcedure
