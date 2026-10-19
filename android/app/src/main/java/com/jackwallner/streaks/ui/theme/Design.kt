package com.jackwallner.streaks.ui.theme

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.streaks.R

class Palette(val dark: Boolean) {
    val bg=Color(if(dark)0xFF0A0612 else 0xFFF5F2FF);val raised=Color(if(dark)0xFF120A22 else 0xFFFFFFFF)
    val card=Color(if(dark)0xFF1E1236 else 0xFFEDE8FC);val grid=Color(if(dark)0xFF2A1A4A else 0xFFD8D0EE)
    val ink=Color(if(dark)0xFFF4ECFF else 0xFF120824);val dim=Color(if(dark)0xFFA395C0 else 0xFF554670)
    val magenta=Color(if(dark)0xFFFF2D95 else 0xFFCC2266);val cyan=Color(if(dark)0xFF2DD4FF else 0xFF0099BB)
    val lime=Color(if(dark)0xFFC8FF00 else 0xFF8AAA00);val amber=Color(if(dark)0xFFFFB020 else 0xFFCC7A00)
    val red=Color(if(dark)0xFFFF3B50 else 0xFFCC2233)
    fun accent(metric: String)=when(metric){"steps"->lime;"exerciseMinutes"->magenta;"standHours"->cyan;"activeEnergy"->amber;"sleepHours"->Color(if(dark)0xFF5DA9FF else 0xFF0D5599);"mindfulMinutes"->Color(if(dark)0xFF7AFF9E else 0xFF2A9955);"distanceMiles"->Color(if(dark)0xFFB088FF else 0xFF7044CC);"workouts"->Color(if(dark)0xFFFF8866 else 0xFFC44A3C);else->cyan}
}
val LocalPalette=staticCompositionLocalOf{Palette(true)}
val Mono=FontFamily(Font(R.font.jetbrains_regular),Font(R.font.jetbrains_medium,FontWeight.Medium),Font(R.font.jetbrains_bold,FontWeight.Bold))
@Composable fun StreakTheme(dark: Boolean,content: @Composable ()->Unit){val p=remember(dark){Palette(dark)};val colors=if(dark)darkColorScheme(primary=p.lime,background=p.bg,surface=p.raised,onSurface=p.ink,onBackground=p.ink,onPrimary=Color.Black)else lightColorScheme(primary=p.lime,background=p.bg,surface=p.raised,onSurface=p.ink,onBackground=p.ink,onPrimary=Color.Black);CompositionLocalProvider(LocalPalette provides p){MaterialTheme(colorScheme=colors,typography=Typography(bodyLarge=androidx.compose.ui.text.TextStyle(fontFamily=Mono,fontSize=15.sp,lineHeight=23.sp),bodyMedium=androidx.compose.ui.text.TextStyle(fontFamily=Mono,fontSize=13.sp,lineHeight=20.sp)),content=content)}}
@Composable fun Label(text: String,modifier: Modifier=Modifier,size: Int=13,color: Color=LocalPalette.current.ink,bold: Boolean=false){Text(text,modifier,fontSize=size.sp,lineHeight=(size*1.35).sp,fontFamily=Mono,fontWeight=if(bold)FontWeight.Bold else FontWeight.Normal,color=color)}
@Composable fun PixelButton(text: String,modifier: Modifier=Modifier,enabled: Boolean=true,primary: Boolean=false,onClick: ()->Unit){val p=LocalPalette.current;val color=if(primary)p.lime else p.cyan;Box(modifier.fillMaxWidth().heightIn(min=50.dp).border(2.dp,if(enabled)color else p.grid).background(if(primary&&enabled)color else p.raised).clickable(enabled=enabled,role=androidx.compose.ui.semantics.Role.Button,onClick=onClick).padding(horizontal=15.dp,vertical=14.dp)){Label(text,size=13,bold=true,color=if(primary&&enabled)Color.Black else if(enabled)p.ink else p.dim)}}
@Composable fun PixelPanel(modifier: Modifier=Modifier,accent: Color=LocalPalette.current.grid,content: @Composable ColumnScope.()->Unit){Column(modifier.fillMaxWidth().border(2.dp,accent).background(LocalPalette.current.card).padding(18.dp),verticalArrangement=Arrangement.spacedBy(10.dp),content=content)}
@Composable fun Section(text: String){Label(text.uppercase(),color=LocalPalette.current.dim,size=12,bold=true)}
