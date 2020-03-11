;--------------------------------------------------------------------------------------------
;  Copyright (c) Fantaisie Software. All rights reserved.
;  Dual licensed under the GPL and Fantaisie Software licenses.
;  See LICENSE and LICENSE-FANTAISIE in the project root for license information.
;--------------------------------------------------------------------------------------------

; PB-native 'diff' implementation
;
; Improvements to be made:
;   Hirschberg linear space refinement
;
; References:
;   https://blog.jcoglan.com/2017/02/15/the-myers-diff-algorithm-part-2/
;   http://simplygenius.net/Article/DiffTutorial1
;   https://blog.robertelder.org/diff-algorithm/
;

CompilerIf (#PB_Compiler_IsMainFile)
  EnableExplicit
CompilerEndIf



;-
;- Constants

CompilerIf (Not Defined(DIFF_MATCH, #PB_Constant))
  Enumeration
    #DIFF_MATCH = 1
    #DIFF_DELETE
    #DIFF_INSERT
  EndEnumeration
CompilerEndIf



;-
;- Structures

CompilerIf (Not Defined(diff_edit, #PB_Structure))
  Structure diff_edit Align #PB_Structure_AlignC
    op.u
    __padding.b[2]  ; on all os
    off.l           ; /* off into s1 if MATCH or DELETE but s2 if INSERT */
    len.l
  EndStructure
CompilerEndIf


; Implement "variable arrays" as PB list items with an index and pointer to a data buffer

Structure varray_entry_PB
  i.i
  ptr.i
EndStructure

Structure varray_PB
  membsize.i
  List mem.varray_entry_PB()
EndStructure




;-
;- Prototypes

PrototypeC diff_idx_fn(*a, idx.l, *context)
PrototypeC diff_cmp_fn(*a, *b, *context)




;-
;- Procedures - varray

Procedure.i varray_new(membsize, *al)
  If (*al = #Null) ; Allocator not implemented, so don't allow it!
    Protected *va.varray_PB = AllocateStructure(varray_PB)
    If *va
      *va\membsize = membsize
    EndIf
  EndIf
  ProcedureReturn *va
EndProcedure

Procedure.i varray_get(*va.varray_PB, idx)
  Protected *mem = #Null
  If *va
    ForEach *va\mem()
      If (*va\mem()\i = idx)
        *mem = *va\mem()\ptr
        Break
      EndIf
    Next
    If (Not *mem)
      *mem = AllocateMemory(*va\membsize)
      If (*mem)
        ResetList(*va\mem())
        InsertElement(*va\mem())
        *va\mem()\i = idx
        *va\mem()\ptr = *mem
      EndIf
    EndIf
  EndIf
  ProcedureReturn *mem
EndProcedure

Procedure varray_del(*va.varray_PB)
  If *va
    ; Free all allocated buffers
    ForEach *va\mem()
      If *va\mem()\ptr
        FreeMemory(*va\mem()\ptr)
      EndIf
    Next
    ClearList(*va\mem())
    FreeStructure(*va)
  EndIf
EndProcedure





;-
;- Procedures - IntArray

Procedure.i BackupIntArray(Array IntArray.i(1))
  Protected *Result
  Protected *Memory = @IntArray(0)
  Protected Size.i = (ArraySize(IntArray()) + 1) * SizeOf(INTEGER)
  If *Memory And (Size > 0)
    *Result = AllocateMemory(Size, #PB_Memory_NoClear)
    If *Result
      CopyMemory(*Memory, *Result, Size)
    EndIf
  EndIf
  ProcedureReturn *Result
EndProcedure

Procedure RestoreIntArray(Array IntArray.i(1), *Memory, Free.i = #False)
  If *Memory
    Protected Size.i = MemorySize(*Memory)
    Protected Elements.i = Size/SizeOf(INTEGER)
    Dim IntArray.i(Elements-1)
    CopyMemory(*Memory, @IntArray(0), Size)
    If (Free)
      FreeMemory(*Memory)
    EndIf
  EndIf
EndProcedure





;-
;- Procedures - Diff

; Macro to allow negative indexing into v array
Macro diff_v(i)
  v(((i) + vCount) % vCount)
EndMacro

; Add an edit step into the varray (or combine it with a previous entry of the same type)
Procedure diff_yield(*ses.varray_PB, *prevOp.INTEGER, op.i, prev_x, prev_y, x, y)
  
  CompilerIf (#False)
    Select (op)
      Case #DIFF_INSERT : Debug "DN (" + Str(prev_x) + ", " + Str(prev_y) + ") -> (" + Str(x) + ", " + Str(y) + ")"
      Case #DIFF_DELETE : Debug "RT (" + Str(prev_x) + ", " + Str(prev_y) + ") -> (" + Str(x) + ", " + Str(y) + ")"
      Case #DIFF_MATCH  : Debug "DG (" + Str(prev_x) + ", " + Str(prev_y) + ") -> (" + Str(x) + ", " + Str(y) + ")"
    EndSelect
  CompilerEndIf
  
  Protected *de.diff_edit
  If (op = *prevOp\i)
    FirstElement(*ses\mem())
    *de = *ses\mem()\ptr
    Select (op)
      Case #DIFF_INSERT
        *de\off - 1
        *de\len + 1
      Case #DIFF_DELETE
        *de\off - 1
        *de\len + 1
      Case #DIFF_MATCH
        *de\off - (x - prev_x)
        *de\len + (x - prev_x)
    EndSelect
  Else
    *de = varray_get(*ses, ListSize(*ses\mem()))
    *de\op = op
    Select (op)
      Case #DIFF_INSERT
        *de\off = prev_y
        *de\len = 1
      Case #DIFF_DELETE
        *de\off = prev_x
        *de\len = 1
      Case #DIFF_MATCH
        *de\off = prev_x
        *de\len = x - prev_x
    EndSelect
  EndIf
  
  *prevOp\i = op
EndProcedure

Procedure.i diff_max(a.i, b.i)
  If (a > b)
    ProcedureReturn a
  EndIf
  ProcedureReturn b
EndProcedure





Procedure.i diff(*a, aoff.i, n.i, *b, boff.i, m.i, idx.diff_idx_fn, cmp.diff_cmp_fn, *context, dmax.i, *ses.varray_PB, *sn.INTEGER, *buf.varray_PB)
  
  ; Strictly validate all inputs accoring to the PB IDE's usage.
  ; This procedure can be generalized in the future.
  
  If (*sn = #Null)
    ProcedureReturn -1
  EndIf
  If (*a = #Null) Or (n < 0) Or (aoff < 0) Or (aoff > n)
    *sn\i = -1
    ProcedureReturn -1
  EndIf
  If (*b = #Null) Or (m < 0) Or (boff < 0) Or (boff > m)
    *sn\i = -1
    ProcedureReturn -1
  EndIf
  If (idx = #Null) Or (cmp = #Null)
    *sn\i = -1
    ProcedureReturn -1
  EndIf
  If (*ses = #Null) Or (*context <> #Null) Or (*buf <> #Null)
    *sn\i = -1
    ProcedureReturn -1
  EndIf
  If (dmax <> 0)
    *sn\i = -1
    ProcedureReturn -1
  EndIf
  
  
  ; Special cases
  
  Protected *de.diff_edit
  If (n = 0) And (m > 0) ; a is empty, copy all contents of b
    *de = varray_get(*ses, 0)
    *de\op = #DIFF_INSERT
    *de\off = 0
    *de\len = m
    *sn\i = 1
    ProcedureReturn m
  ElseIf (n > 0) And (m = 0) ; b is empty, delete all contents of a
    *de = varray_get(*ses, 0)
    *de\op = #DIFF_DELETE
    *de\off = 0
    *de\len = n
    *sn\i = 1
    ProcedureReturn n
  ElseIf (n = 0) And (m = 0) ; a and b are empty - do nothing
    *sn\i = 0
    ProcedureReturn 0
  EndIf
  
  
  
  ;- - Myers diff algorithm
  
  ;- - Find shortest number of edits
  
  ; Rightward (increase x)       = delete from old
  ; Downward  (increase y)       = insert from new
  ; Diagonal  (increase x and y) = copy from old (match)
  
  Protected NumEdits.i = 0
  Protected max.i = n + m ; Maximum number of edits needed
  
  Protected x.i, y.i ; Number of deletions and insertions
  Protected d.i, k.i ; d is number of edits so far, k is always x - y
  
  
  ;Protected vCount.i = 2 * max + 2
  Protected vCount.i = 1 * max + 2 ; half-memory version
  Dim v.i(vCount - 1)
  NewList vBackup.i() ; List of buffers which store past copies of v()
  
  
  
  For d = 0 To max
    If (d >= 0)
      AddElement(vBackup())
      vBackup() = BackupIntArray(v()) ; Store a copy of array v, for backtracking later
    EndIf
    
    ;For k = -d To d Step 2
    For k = -(d - 2*diff_max(0, d-m)) To (d - 2*diff_max(0, d-n)) Step 2 ; half-memory version
      
      If (k = -d) Or ((k <> d) And (diff_v(k-1) < diff_v(k+1)))
        x = diff_v(k+1) ; Move down
      Else
        x = diff_v(k-1) + 1 ; Move right
      EndIf
      y = x - k
      
      ; cmp result 0 = equal, 1 = different
      While (x < n) And (y < m) And (cmp(idx(*a, x, #Null), idx(*b, y, #Null), #Null) = 0)
        ; Move diagonally
        x + 1
        y + 1
      Wend
      
      diff_v(k) = x
      
      If (x >= n) And (y >= m)
        NumEdits = d
        Break 2
      EndIf
      
    Next k
  Next d
  
  CompilerIf (#False)
    Debug "Edits: " + Str(NumEdits)
    Debug "Backups: " + Str(ListSize(vBackup()))
  CompilerEndIf
  
  
  
  
  
  ;- - Backtrack to define the edit operations
  
  Protected prev_k.i, prev_x.i, prev_y.i
  Protected PrevOp.i = -1
  
  If (d > 0)
    x = n
    y = m
    For d = NumEdits To 0 Step -1
      LastElement(vBackup())
      RestoreIntArray(v(), vBackup(), #True)
      DeleteElement(vBackup())
      
      k = x - y
      If (k = -d) Or ((k <> d) And (diff_v(k-1) < diff_v(k+1)))
        prev_k = k + 1
      Else
        prev_k = k - 1
      EndIf
      
      prev_x = diff_v(prev_k)
      prev_y = prev_x - prev_k
      
      While (x > prev_x) And (y > prev_y)
        ; Yield diagonal move
        diff_yield(*ses, @PrevOp, #DIFF_MATCH, x-1, y-1, x, y)
        x - 1
        y - 1
      Wend
      If (x = 0) And (y = 0)
        Break
      EndIf
      
      ; Yield down or right move
      If (x = prev_x)
        diff_yield(*ses, @PrevOp, #DIFF_INSERT, prev_x, prev_y, x, y)
      ElseIf (y = prev_y)
        diff_yield(*ses, @PrevOp, #DIFF_DELETE, prev_x, prev_y, x, y)
      EndIf
      
      x = prev_x
      y = prev_y
      
      If (x = 0) And (y = 0)
        Break
      EndIf
      
    Next d
    
  Else
    diff_yield(*ses, @PrevOp, #DIFF_MATCH, 0, 0, n, m) ; The inputs match - return one big MATCH operation
  EndIf
  
  
  
  ; Free any unused copies of array v
  While (ListSize(vBackup()))
    LastElement(vBackup())
    FreeMemory(vBackup())
    DeleteElement(vBackup())
  Wend
  
  ; List was built backwards, without knowing final size - so re-index it forwards
  ForEach *ses\mem()
    *ses\mem()\i = ListIndex(*ses\mem())
  Next
  
  ; Return number of operations (including MATCH) - not number of edited lines
  *sn\i = ListSize(*ses\mem())
  
  ; Return number of edited lines
  ProcedureReturn NumEdits
EndProcedure

;-
