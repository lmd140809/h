// The 4 methods patched by the Mizze IFix patch
// (everything else in mz.full.cs is a helper/lambda they call)

// ------------------------------------------------------------
// COW.GameFacade.get_UIModelRole  -> code slot 155
// ------------------------------------------------------------
static object COW_GameFacade_get_UIModelRole(object arg0)
{
  sub_39();
  if (COW.GameFacade.m_modelRole) goto L7;
  COW.GameFacade.m_modelRole = GCommon.UIModelManager.GetModel(GCommon.SingletonModule<GCommon.UIModelManager>.get_instance());
L7:
  return COW.GameFacade.m_modelRole;
}

// ------------------------------------------------------------
// COW.GamePlay.Player.IsReallyInStealth  -> code slot 214
// ------------------------------------------------------------
static object COW_GamePlay_Player_IsReallyInStealth(object arg0)
{
  loc0 = COW.GamePlay.Player.IsInStealth(arg0);
  sub_39();
  return loc0;
}

// ------------------------------------------------------------
// COW.GamePlay.Player.get_LastAimingInfoFromWeapon  -> code slot 124
// ------------------------------------------------------------
static object COW_GamePlay_Player_get_LastAimingInfoFromWeapon(object arg0)
{
  loc0 = arg0.FDMIEDDNCEC;
  sub_160(arg0, loc0);
  return loc0;
}

// ------------------------------------------------------------
// COW.GamePlay.SceneEditBoxSelectTool.OnGUI  -> code slot 226
// ------------------------------------------------------------
static object COW_GamePlay_SceneEditBoxSelectTool_OnGUI(object arg0)
{
  loc0 = default(UnityEngine.EventType);
  loc4 = default(UnityEngine.Color);
  loc5 = default(UnityEngine.Color);
  loc6 = default(UnityEngine.Matrix4x4);
  loc11 = default(UnityEngine.Vector3);
  if (!COW.GamePlay.SceneEditBoxSelectTool.Mz66598fcf607614) goto L14;
  return;
L14:
  if (UnityEngine.Object.op_Equality(arg0, null)) goto L32;
  if (!UnityEngine.Event.get_current()) goto L32;
  if (UnityEngine.Object.op_Equality(UnityEngine.Component.get_gameObject(arg0), null)) goto L32;
  if (!System.String.op_Inequality(UnityEngine.Object.get_name(UnityEngine.Component.get_gameObject(arg0)), "__mizze_driver")) goto L33;
L32:
  return;
L33:
  COW.GamePlay.SceneEditBoxSelectTool.Mz64dcf85b02f6b9 = UnityEngine.GUIUtility.GetControlID(5069366, 2);
  loc0 = UnityEngine.Event.get_type(UnityEngine.Event.get_current());
  if (loc0 == 11) goto L46;
  if (loc0 != 21) goto L48;
L46:
  sub_135();
  return;
L48:
  if (loc0 != 30) goto L54;
  loc0 = 0;
  goto L65;
L54:
  if (loc0 != 31) goto L60;
  loc0 = 1;
  goto L65;
L60:
  if (loc0 != 32) goto L65;
  loc0 = 3;
L65:
  if (loc0 == 7) goto L77;
  if (!loc0) goto L77;
  if (loc0 == 3) goto L77;
  if (loc0 == 1) goto L77;
  return;
L77:
  loc1 = (loc0 == 1);
  loc2 = ((loc0 == 7) == 0);
  COW.GamePlay.SceneEditBoxSelectTool.Mz3b11926a694ab0 = System.Threading.Thread.get_ManagedThreadId(System.Threading.Thread.get_CurrentThread());
  loc3 = COW.GamePlay.SceneEditBoxSelectTool.Mz64ab73afbd2e57;
  COW.GamePlay.SceneEditBoxSelectTool.Mz64ab73afbd2e57 = (loc0 == 7);
  loc4 = UnityEngine.GUI.get_color();
  loc5 = UnityEngine.GUI.get_contentColor();
  loc6 = UnityEngine.GUI.get_matrix();
  loc7 = null;
  loc8 = 0;
  COW.GamePlay.SceneEditBoxSelectTool.Mz66598fcf607614 = 1;
  // try {
  // try {
  UnityEngine.GUI.set_matrix(UnityEngine.Matrix4x4.get_identity());
  if (!COW.GamePlay.SceneEditBoxSelectTool.Mz64ab73afbd2e57) goto L113;
  sub_10();
L113:
  sub_19();
  if (sub_227(loc0)) goto L119;
  // Leave 281
  goto L263;
L119:
  if (UnityEngine.Event.get_type(UnityEngine.Event.get_current()) == loc0) goto L126;
  UnityEngine.Event.set_type(UnityEngine.Event.get_current(), loc0);
L126:
  sub_109();
  if (!COW.GamePlay.SceneEditBoxSelectTool.Mz64ab73afbd2e57) goto L147;
  UnityEngine.GUI.set_contentColor(new UnityEngine.Color(1.0, 1.0, 1.0, 1.0));
  sub_137();
  sub_130();
  sub_102();
  if (!COW.GamePlay.SceneEditBoxSelectTool.Mz89bbee0da94424) goto L147;
  loc7 = UnityEngine.GUISkin.get_font(UnityEngine.GUI.get_skin());
  UnityEngine.GUIStyle.SetDefaultFont(COW.GamePlay.SceneEditBoxSelectTool.Mz89bbee0da94424);
  loc8 = 1;
L147:
  if (UnityEngine.Event.get_type(UnityEngine.Event.get_current()) != 7) goto L225;
  sub_156();
  sub_36();
  sub_157();
  COW.GamePlay.SceneEditBoxSelectTool.Mz211e9503dd1c30 = ((UnityEngine.Mathf.Sin((UnityEngine.Time.get_realtimeSinceStartup() * 2.4000000953674316)) + 1.0) * 0.5);
  loc9 = UnityEngine.Mathf.Clamp((UnityEngine.Time.get_unscaledDeltaTime() * 14.0), 0.0, 1.0);
  if (COW.GamePlay.SceneEditBoxSelectTool.Mzcd43bbf61bc70b) goto L175;
  goto L176;
L175:
L176:
  COW.GamePlay.SceneEditBoxSelectTool.Mz49767de0218b23 = sub_117(0, ((float)1), loc9);
  if (COW.GamePlay.SceneEditBoxSelectTool.Mzcd43bbf61bc70b) goto L185;
  if (COW.GamePlay.SceneEditBoxSelectTool.Mz49767de0218b23 <= 0.019999999552965164) goto L219;
L185:
  COW.GamePlay.SceneEditBoxSelectTool.Mz2d44a74bbfa1db = sub_117(COW.GamePlay.SceneEditBoxSelectTool.Mz2d44a74bbfa1db, ((float)COW.GamePlay.SceneEditBoxSelectTool.Mzf0b1bfa40a91f1), loc9);
  loc10 = 0;
  goto L214;
L194:
  if (COW.GamePlay.SceneEditBoxSelectTool.Mz85da9e0b99dc4e[loc10]) goto L205;
  goto L206;
L205:
L206:
  loc10[COW.GamePlay.SceneEditBoxSelectTool.Mz7abefbe6fd269e[loc10]] = sub_117(0, ((float)1), loc9);
  loc10 = (loc10 + 1);
L214:
  if (loc10 < ((int)COW.GamePlay.SceneEditBoxSelectTool.Mz85da9e0b99dc4e.Length)) goto L194;
L219:
  if (!sub_204()) goto L224;
  sub_22();
  sub_178();
  goto L225;
L224:
  sub_90();
L225:
  if (!COW.GamePlay.SceneEditBoxSelectTool.Mz64ab73afbd2e57) goto L247;
  if (COW.GamePlay.SceneEditBoxSelectTool.Mz72f8b04024d0d5 == COW.GamePlay.SceneEditBoxSelectTool.Mz9737070ba1bd5a) goto L245;
  loc11 = default(UnityEngine.Vector3);
  COW.GamePlay.SceneEditBoxSelectTool.Mz3d748ccbc35c64 = UnityEngine.Matrix4x4.TRS(loc11, UnityEngine.Quaternion.Euler(0.0, 0.0, 0.0), new UnityEngine.Vector3(COW.GamePlay.SceneEditBoxSelectTool.Mz9737070ba1bd5a, COW.GamePlay.SceneEditBoxSelectTool.Mz9737070ba1bd5a, 1.0));
  COW.GamePlay.SceneEditBoxSelectTool.Mz72f8b04024d0d5 = COW.GamePlay.SceneEditBoxSelectTool.Mz9737070ba1bd5a;
L245:
  UnityEngine.GUI.set_matrix(COW.GamePlay.SceneEditBoxSelectTool.Mz3d748ccbc35c64);
L247:
  if (COW.GamePlay.SceneEditBoxSelectTool.Mz26a31d67abf822) goto L256;
  sub_180();
  if (COW.GamePlay.SceneEditBoxSelectTool.Mzcd43bbf61bc70b) goto L255;
  if (COW.GamePlay.SceneEditBoxSelectTool.Mz49767de0218b23 <= 0.019999999552965164) goto L256;
L255:
  sub_208();
L256:
  goto L261;
  // } // end try
  // catch (System.Exception) {
  goto L261;
  // } // end catch
L261:
  // Leave 281
  goto L263;
  // } // end try
  // finally {
L263:
  COW.GamePlay.SceneEditBoxSelectTool.Mz66598fcf607614 = 0;
  COW.GamePlay.SceneEditBoxSelectTool.Mz64ab73afbd2e57 = loc3;
  sub_203(loc1, loc2);
  if (!loc8) goto L274;
  UnityEngine.GUIStyle.SetDefaultFont(loc7);
L274:
  UnityEngine.GUI.set_color(loc4);
  UnityEngine.GUI.set_contentColor(loc5);
  UnityEngine.GUI.set_matrix(loc6);
  // Endfinally -1
  // } // end finally
L281:
  return;
}

