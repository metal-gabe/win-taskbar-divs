// Native helpers for WinTaskbarDivs: folder icon extraction, recoloring, overlay
// drawing, multi-size ICO writing, and .lnk creation with an AppUserModel.ID.
// Compiled once per session via Add-Type (see Native.ps1).

using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;

namespace WinTaskbarDivs
{
   public enum OverlayKind { Icon, Text, Image }
   public enum OverlayPlacement { Center, Badge }

   public sealed class IconSpec
   {
      // null => keep the stock folder color
      public Color? FolderColor;
      // null => pick automatically for contrast
      public Color? OverlayColor;
      public OverlayKind Kind;
      // icon character(s), literal text, or image path
      public string Value;
      public OverlayPlacement Placement = OverlayPlacement.Center;
      public string IconFont = "Segoe Fluent Icons";
      public string TextFont = "Segoe UI";
   }

   public static class IconRenderer
   {
      public static readonly int[] Sizes = { 16, 20, 24, 32, 40, 48, 64, 256 };

      // ---------------------------------------------------------------------
      // Folder extraction
      // ---------------------------------------------------------------------

      [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
      private struct SHSTOCKICONINFO
      {
         public uint cbSize;
         public IntPtr hIcon;
         public int iSysImageIndex;
         public int iIcon;
         [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
         public string szPath;
      }

      [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
      private static extern int SHGetStockIconInfo(uint siid, uint flags, ref SHSTOCKICONINFO info);

      [DllImport("user32.dll", CharSet = CharSet.Unicode)]
      private static extern uint PrivateExtractIcons(string file, int index, int cx, int cy, IntPtr[] icons, int[] ids, uint count, uint flags);

      [DllImport("user32.dll")]
      private static extern bool DestroyIcon(IntPtr hIcon);

      [StructLayout(LayoutKind.Sequential)]
      private struct ICONINFO
      {
         public bool fIcon;
         public int xHotspot;
         public int yHotspot;
         public IntPtr hbmMask;
         public IntPtr hbmColor;
      }

      [DllImport("user32.dll")]
      private static extern bool GetIconInfo(IntPtr hIcon, out ICONINFO info);

      [DllImport("gdi32.dll")]
      private static extern bool DeleteObject(IntPtr obj);

      [DllImport("gdi32.dll")]
      private static extern int GetDIBits(IntPtr hdc, IntPtr hbm, uint start, uint lines, byte[] bits, ref BITMAPINFOHEADER bmi, uint usage);

      [DllImport("user32.dll")]
      private static extern IntPtr GetDC(IntPtr hwnd);

      [DllImport("user32.dll")]
      private static extern int ReleaseDC(IntPtr hwnd, IntPtr hdc);

      [StructLayout(LayoutKind.Sequential)]
      private struct BITMAPINFOHEADER
      {
         public uint biSize;
         public int biWidth;
         public int biHeight;
         public ushort biPlanes;
         public ushort biBitCount;
         public uint biCompression;
         public uint biSizeImage;
         public int biXPelsPerMeter;
         public int biYPelsPerMeter;
         public uint biClrUsed;
         public uint biClrImportant;
         // room for the color table GetDIBits may write for BI_RGB 32bpp (none) + slack
         [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)]
         public uint[] colors;
      }

      // Returns "path,index" of the shell's stock folder icon (SIID_FOLDER = 3).
      public static string FolderIconLocation()
      {
         var info = new SHSTOCKICONINFO();
         info.cbSize = (uint)Marshal.SizeOf(typeof(SHSTOCKICONINFO));
         int hr = SHGetStockIconInfo(3, 0, ref info);
         if (hr != 0) throw new COMException("SHGetStockIconInfo failed", hr);
         return info.szPath + "," + info.iIcon;
      }

      // Extracts the stock folder icon at exactly size x size as a 32bpp ARGB bitmap.
      public static Bitmap ExtractFolder(int size)
      {
         string loc = FolderIconLocation();
         int comma = loc.LastIndexOf(',');
         string file = Environment.ExpandEnvironmentVariables(loc.Substring(0, comma));
         int index = int.Parse(loc.Substring(comma + 1));

         var handles = new IntPtr[1];
         var ids = new int[1];
         uint got = PrivateExtractIcons(file, index, size, size, handles, ids, 1, 0);
         if (got == 0 || got == 0xFFFFFFFF || handles[0] == IntPtr.Zero)
            throw new InvalidOperationException("Could not extract folder icon from " + loc);
         try { return HIconToBitmap(handles[0]); }
         finally { DestroyIcon(handles[0]); }
      }

      // Icon.ToBitmap() can drop alpha for some HICONs; read the color DIB directly.
      private static Bitmap HIconToBitmap(IntPtr hIcon)
      {
         ICONINFO ii;
         if (!GetIconInfo(hIcon, out ii)) throw new InvalidOperationException("GetIconInfo failed");
         try
         {
            using (var probe = Image.FromHbitmap(ii.hbmColor))
            {
               int w = probe.Width, h = probe.Height;
               var bmi = new BITMAPINFOHEADER();
               bmi.biSize = 40;
               bmi.biWidth = w;
               bmi.biHeight = -h; // top-down
               bmi.biPlanes = 1;
               bmi.biBitCount = 32;
               bmi.colors = new uint[256];
               var bits = new byte[w * h * 4];
               IntPtr hdc = GetDC(IntPtr.Zero);
               try
               {
                  if (GetDIBits(hdc, ii.hbmColor, 0, (uint)h, bits, ref bmi, 0) == 0)
                     throw new InvalidOperationException("GetDIBits failed");
               }
               finally { ReleaseDC(IntPtr.Zero, hdc); }

               var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
               var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
               for (int y = 0; y < h; y++)
                  Marshal.Copy(bits, y * w * 4, data.Scan0 + y * data.Stride, w * 4);
               bmp.UnlockBits(data);
               return bmp;
            }
         }
         finally
         {
            if (ii.hbmColor != IntPtr.Zero) DeleteObject(ii.hbmColor);
            if (ii.hbmMask != IntPtr.Zero) DeleteObject(ii.hbmMask);
         }
      }

      // ---------------------------------------------------------------------
      // Color math
      // ---------------------------------------------------------------------

      public static void ToHsl(Color c, out double h, out double s, out double l)
      {
         double r = c.R / 255.0, g = c.G / 255.0, b = c.B / 255.0;
         double max = Math.Max(r, Math.Max(g, b)), min = Math.Min(r, Math.Min(g, b));
         l = (max + min) / 2;
         if (max == min) { h = 0; s = 0; return; }
         double d = max - min;
         s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
         if (max == r) h = (g - b) / d + (g < b ? 6 : 0);
         else if (max == g) h = (b - r) / d + 2;
         else h = (r - g) / d + 4;
         h /= 6;
      }

      public static Color FromHsl(int a, double h, double s, double l)
      {
         h = h - Math.Floor(h);
         s = Clamp01(s);
         l = Clamp01(l);
         double r, g, b;
         if (s == 0) { r = g = b = l; }
         else
         {
            double q = l < 0.5 ? l * (1 + s) : l + s - l * s;
            double p = 2 * l - q;
            r = HueToRgb(p, q, h + 1.0 / 3);
            g = HueToRgb(p, q, h);
            b = HueToRgb(p, q, h - 1.0 / 3);
         }
         return Color.FromArgb(a, ToByte(r), ToByte(g), ToByte(b));
      }

      private static double HueToRgb(double p, double q, double t)
      {
         if (t < 0) t += 1;
         if (t > 1) t -= 1;
         if (t < 1.0 / 6) return p + (q - p) * 6 * t;
         if (t < 1.0 / 2) return q;
         if (t < 2.0 / 3) return p + (q - p) * (2.0 / 3 - t) * 6;
         return p;
      }

      private static double Clamp01(double v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }
      private static int ToByte(double v) { return (int)Math.Round(Clamp01(v) * 255); }

      public static double Luminance(Color c)
      {
         Func<double, double> lin = v => { v /= 255.0; return v <= 0.03928 ? v / 12.92 : Math.Pow((v + 0.055) / 1.055, 2.4); };
         return 0.2126 * lin(c.R) + 0.7152 * lin(c.G) + 0.0722 * lin(c.B);
      }

      // ---------------------------------------------------------------------
      // Recolor: shift hue, scale saturation, and remap lightness so the folder's
      // shading survives while its overall tone matches the target color.
      // ---------------------------------------------------------------------

      public static void Recolor(Bitmap bmp, Color target)
      {
         int w = bmp.Width, h = bmp.Height;
         var rect = new Rectangle(0, 0, w, h);
         var data = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
         var px = new byte[data.Stride * h];
         Marshal.Copy(data.Scan0, px, 0, px.Length);

         // Base tone: alpha-weighted average over the opaque, colored pixels.
         double sumS = 0, sumL = 0, sumW = 0;
         double sumHx = 0, sumHy = 0;
         for (int i = 0; i < px.Length; i += 4)
         {
            int a = px[i + 3];
            if (a < 128) continue;
            double ph, ps, pl;
            ToHsl(Color.FromArgb(px[i + 2], px[i + 1], px[i]), out ph, out ps, out pl);
            if (ps < 0.15) continue;
            double wgt = a / 255.0;
            sumHx += Math.Cos(ph * 2 * Math.PI) * wgt;
            sumHy += Math.Sin(ph * 2 * Math.PI) * wgt;
            sumS += ps * wgt;
            sumL += pl * wgt;
            sumW += wgt;
         }
         if (sumW == 0) { bmp.UnlockBits(data); return; }
         double baseH = Math.Atan2(sumHy, sumHx) / (2 * Math.PI);
         double baseS = sumS / sumW, baseL = sumL / sumW;

         double tH, tS, tL;
         ToHsl(target, out tH, out tS, out tL);

         for (int i = 0; i < px.Length; i += 4)
         {
            int a = px[i + 3];
            if (a == 0) continue;
            double ph, ps, pl;
            ToHsl(Color.FromArgb(px[i + 2], px[i + 1], px[i]), out ph, out ps, out pl);

            double nh = ph + (tH - baseH);
            double ns = baseS > 0 ? ps * (tS / baseS) : tS;
            double nl = tL < baseL
               ? pl * (tL / baseL)
               : 1 - (1 - pl) * ((1 - tL) / (1 - baseL));

            var c = FromHsl(a, nh, ns, nl);
            px[i] = c.B;
            px[i + 1] = c.G;
            px[i + 2] = c.R;
         }

         Marshal.Copy(px, 0, data.Scan0, px.Length);
         bmp.UnlockBits(data);
      }

      // Average opaque color of the bitmap (used to choose an overlay color).
      public static Color AverageColor(Bitmap bmp)
      {
         long r = 0, g = 0, b = 0, n = 0;
         for (int y = 0; y < bmp.Height; y++)
            for (int x = 0; x < bmp.Width; x++)
            {
               var c = bmp.GetPixel(x, y);
               if (c.A < 200) continue;
               r += c.R; g += c.G; b += c.B; n++;
            }
         if (n == 0) return Color.Gray;
         return Color.FromArgb((int)(r / n), (int)(g / n), (int)(b / n));
      }

      // Dark shade of the folder hue on light folders, near-white tint on dark ones.
      public static Color AutoOverlayColor(Color folder)
      {
         double h, s, l;
         ToHsl(folder, out h, out s, out l);
         if (Luminance(folder) > 0.30)
            return FromHsl(235, h, Math.Min(1, s * 0.9 + 0.1), 0.20);
         return FromHsl(240, h, s * 0.25, 0.96);
      }

      // ---------------------------------------------------------------------
      // Rendering
      // ---------------------------------------------------------------------

      private static Rectangle OpaqueBounds(Bitmap bmp)
      {
         int minX = bmp.Width, minY = bmp.Height, maxX = -1, maxY = -1;
         for (int y = 0; y < bmp.Height; y++)
            for (int x = 0; x < bmp.Width; x++)
            {
               if (bmp.GetPixel(x, y).A < 64) continue;
               if (x < minX) minX = x;
               if (y < minY) minY = y;
               if (x > maxX) maxX = x;
               if (y > maxY) maxY = y;
            }
         if (maxX < 0) return new Rectangle(0, 0, bmp.Width, bmp.Height);
         return Rectangle.FromLTRB(minX, minY, maxX + 1, maxY + 1);
      }

      public static Bitmap Render(IconSpec spec, int size)
      {
         var bmp = ExtractFolder(size);
         if (spec.FolderColor.HasValue) Recolor(bmp, spec.FolderColor.Value);

         Color folderTone = spec.FolderColor.HasValue ? spec.FolderColor.Value : AverageColor(bmp);
         Color overlay = spec.OverlayColor.HasValue ? spec.OverlayColor.Value : AutoOverlayColor(folderTone);

         var body = OpaqueBounds(bmp);
         using (var g = Graphics.FromImage(bmp))
         {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.CompositingQuality = CompositingQuality.HighQuality;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;

            RectangleF box;
            if (spec.Placement == OverlayPlacement.Badge)
            {
               float d = (float)Math.Max(8, Math.Round(size * (size <= 32 ? 0.55 : 0.44)));
               float inset = size * 0.03f;
               var circle = new RectangleF(body.Right - d - inset, body.Bottom - d - inset, d, d);
               using (var fill = new SolidBrush(overlay))
                  g.FillEllipse(fill, circle);
               float pad = d * 0.22f;
               box = RectangleF.Inflate(circle, -pad, -pad);
               // inside the badge, draw in the folder color unless it would vanish
               Color badgeFill = overlay;
               overlay = Color.FromArgb(255, folderTone);
               if (ContrastRatio(overlay, badgeFill) < 2.5)
                  overlay = Luminance(badgeFill) > 0.3 ? Color.FromArgb(255, 32, 32, 32) : Color.White;
            }
            else
            {
               // The front panel of the Win11 folder starts ~22% down the opaque area.
               float frontTop = body.Top + body.Height * 0.22f;
               float frontH = body.Bottom - frontTop;
               // Taskbar sizes (24-40px) need a proportionally bigger overlay to read.
               float frac = size <= 32 ? 0.90f : (size <= 48 ? 0.80f : 0.68f);
               float side = Math.Min(body.Width * 0.8f, frontH * frac);
               float cx = body.Left + body.Width / 2f;
               float cy = frontTop + frontH / 2f;
               box = new RectangleF(cx - side / 2, cy - side / 2, side, side);
            }

            switch (spec.Kind)
            {
               case OverlayKind.Icon:
                  DrawTextPath(g, spec.Value, spec.IconFont, FontStyle.Regular, box, overlay, false, size);
                  break;
               case OverlayKind.Text:
                  DrawTextPath(g, spec.Value, spec.TextFont, FontStyle.Bold, box, overlay, true, size);
                  break;
               case OverlayKind.Image:
                  DrawImage(g, spec.Value, box, size);
                  break;
            }
         }
         return bmp;
      }

      private static double ContrastRatio(Color a, Color b)
      {
         double la = Luminance(a) + 0.05, lb = Luminance(b) + 0.05;
         return la > lb ? la / lb : lb / la;
      }

      private static void DrawTextPath(Graphics g, string text, string fontName, FontStyle style, RectangleF box, Color color, bool isText, int size)
      {
         using (var family = new FontFamily(fontName))
         using (var path = new GraphicsPath())
         using (var fmt = (StringFormat)StringFormat.GenericTypographic.Clone())
         {
            fmt.FormatFlags |= StringFormatFlags.NoWrap;
            path.AddString(text, family, (int)style, 100f, PointF.Empty, fmt);
            var b = path.GetBounds();
            if (b.Width <= 0 || b.Height <= 0) return;

            // Text gets a wider, shorter box than a square icon.
            RectangleF target = box;
            if (isText)
            {
               float tw = box.Width * 1.15f, th = box.Height * 0.62f;
               target = new RectangleF(box.X + (box.Width - tw) / 2, box.Y + (box.Height - th) / 2, tw, th);
            }

            float scale = Math.Min(target.Width / b.Width, target.Height / b.Height);
            using (var m = new Matrix())
            {
               m.Translate(target.X + target.Width / 2, target.Y + target.Height / 2);
               m.Scale(scale, scale);
               m.Translate(-(b.X + b.Width / 2), -(b.Y + b.Height / 2));
               path.Transform(m);
            }
            using (var brush = new SolidBrush(color))
               g.FillPath(brush, path);

            // Fluent icons are hairline at small sizes; stroke the outline to embolden.
            if (size <= 48)
            {
               using (var pen = new Pen(color, size * 0.035f) { LineJoin = LineJoin.Round })
                  g.DrawPath(pen, path);
            }
         }
      }

      private static Bitmap LoadImage(string file, int size)
      {
         if (file.EndsWith(".ico", StringComparison.OrdinalIgnoreCase))
         {
            using (var ico = new Icon(file, Math.Max(size, 64), Math.Max(size, 64)))
               return ico.ToBitmap();
         }
         // Load through a copy so the source file isn't locked.
         var bytes = File.ReadAllBytes(file);
         using (var ms = new MemoryStream(bytes))
         using (var img = Image.FromStream(ms))
            return new Bitmap(img);
      }

      private static void DrawImage(Graphics g, string file, RectangleF box, int size)
      {
         using (var img = LoadImage(file, size))
         {
            float scale = Math.Min(box.Width / img.Width, box.Height / img.Height);
            float w = img.Width * scale, h = img.Height * scale;
            g.DrawImage(img, new RectangleF(box.X + (box.Width - w) / 2, box.Y + (box.Height - h) / 2, w, h));
         }
      }

      // ---------------------------------------------------------------------
      // Output
      // ---------------------------------------------------------------------

      public static List<Bitmap> RenderAll(IconSpec spec)
      {
         var list = new List<Bitmap>();
         foreach (int s in Sizes) list.Add(Render(spec, s));
         return list;
      }

      // Writes a multi-size .ico: 32bpp DIB entries below 256px, PNG for 256px.
      public static void WriteIco(string path, IList<Bitmap> images)
      {
         var blobs = new List<byte[]>();
         foreach (var img in images)
            blobs.Add(img.Width >= 256 ? PngBytes(img) : DibBytes(img));

         using (var fs = new FileStream(path, FileMode.Create, FileAccess.Write))
         using (var w = new BinaryWriter(fs))
         {
            w.Write((ushort)0);
            w.Write((ushort)1);
            w.Write((ushort)images.Count);
            int offset = 6 + 16 * images.Count;
            for (int i = 0; i < images.Count; i++)
            {
               var img = images[i];
               w.Write((byte)(img.Width >= 256 ? 0 : img.Width));
               w.Write((byte)(img.Height >= 256 ? 0 : img.Height));
               w.Write((byte)0);
               w.Write((byte)0);
               w.Write((ushort)1);
               w.Write((ushort)32);
               w.Write((uint)blobs[i].Length);
               w.Write((uint)offset);
               offset += blobs[i].Length;
            }
            foreach (var b in blobs) w.Write(b);
         }
      }

      private static byte[] PngBytes(Bitmap img)
      {
         using (var ms = new MemoryStream())
         {
            img.Save(ms, ImageFormat.Png);
            return ms.ToArray();
         }
      }

      private static byte[] DibBytes(Bitmap img)
      {
         int w = img.Width, h = img.Height;
         int maskStride = ((w + 31) / 32) * 4;
         var data = img.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
         var px = new byte[data.Stride * h];
         Marshal.Copy(data.Scan0, px, 0, px.Length);
         int stride = data.Stride;
         img.UnlockBits(data);

         using (var ms = new MemoryStream())
         using (var bw = new BinaryWriter(ms))
         {
            bw.Write((uint)40);
            bw.Write(w);
            bw.Write(h * 2);
            bw.Write((ushort)1);
            bw.Write((ushort)32);
            bw.Write((uint)0);
            bw.Write((uint)(w * h * 4 + maskStride * h));
            bw.Write(0);
            bw.Write(0);
            bw.Write((uint)0);
            bw.Write((uint)0);
            // XOR (color) bitmap, bottom-up BGRA
            for (int y = h - 1; y >= 0; y--)
               bw.Write(px, y * stride, w * 4);
            // AND mask: transparent where alpha is 0
            for (int y = h - 1; y >= 0; y--)
            {
               var row = new byte[maskStride];
               for (int x = 0; x < w; x++)
                  if (px[y * stride + x * 4 + 3] == 0) row[x / 8] |= (byte)(0x80 >> (x % 8));
               bw.Write(row);
            }
            return ms.ToArray();
         }
      }

      // Preview sheet. Top row: every size at 1:1. Bottom row: the taskbar sizes
      // (24/32/40px) magnified 4x with nearest-neighbor so their pixels can be judged.
      // Left half is light, right half dark, matching both taskbar themes.
      public static void SavePreview(string path, IList<Bitmap> images)
      {
         const int pad = 16, zoom = 4;
         var taskbar = new List<Bitmap>();
         foreach (var img in images)
            if (img.Width == 24 || img.Width == 32 || img.Width == 40) taskbar.Add(img);

         int row1W = pad, row1H = 0;
         foreach (var img in images) { row1W += img.Width + pad; row1H = Math.Max(row1H, img.Height); }
         int row2W = pad, row2H = 0;
         foreach (var img in taskbar) { row2W += img.Width * zoom + pad; row2H = Math.Max(row2H, img.Height * zoom); }

         int width = Math.Max(row1W, row2W);
         int height = pad + row1H + pad + (row2H > 0 ? row2H + pad : 0);
         using (var sheet = new Bitmap(width, height, PixelFormat.Format32bppArgb))
         using (var g = Graphics.FromImage(sheet))
         {
            using (var light = new SolidBrush(Color.FromArgb(242, 242, 242)))
            using (var dark = new SolidBrush(Color.FromArgb(32, 32, 32)))
            {
               g.FillRectangle(light, 0, 0, width / 2, height);
               g.FillRectangle(dark, width / 2, 0, width - width / 2, height);
            }

            int x = pad, baseline = pad + row1H;
            foreach (var img in images)
            {
               g.DrawImageUnscaled(img, x, baseline - img.Height);
               x += img.Width + pad;
            }

            g.InterpolationMode = InterpolationMode.NearestNeighbor;
            g.PixelOffsetMode = PixelOffsetMode.Half;
            x = pad;
            baseline = pad + row1H + pad + row2H;
            foreach (var img in taskbar)
            {
               int w = img.Width * zoom, h = img.Height * zoom;
               g.DrawImage(img, new Rectangle(x, baseline - h, w, h));
               x += w + pad;
            }
            sheet.Save(path, ImageFormat.Png);
         }
      }
   }

   // -------------------------------------------------------------------------
   // Shortcuts (.lnk) with System.AppUserModel.ID
   // -------------------------------------------------------------------------

   [ComImport, Guid("000214F9-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
   internal interface IShellLinkW
   {
      void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder file, int cch, IntPtr pfd, uint flags);
      void GetIDList(out IntPtr ppidl);
      void SetIDList(IntPtr pidl);
      void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder name, int cch);
      void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string name);
      void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder dir, int cch);
      void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string dir);
      void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder args, int cch);
      void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string args);
      void GetHotkey(out short hotkey);
      void SetHotkey(short hotkey);
      void GetShowCmd(out int showCmd);
      void SetShowCmd(int showCmd);
      void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder path, int cch, out int index);
      void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string path, int index);
      void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string path, uint reserved);
      void Resolve(IntPtr hwnd, uint flags);
      void SetPath([MarshalAs(UnmanagedType.LPWStr)] string file);
   }

   [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
   internal class CShellLink { }

   [StructLayout(LayoutKind.Sequential, Pack = 4)]
   internal struct PROPERTYKEY
   {
      public Guid fmtid;
      public uint pid;
   }

   [StructLayout(LayoutKind.Explicit, Size = 24)]
   internal struct PROPVARIANT
   {
      [FieldOffset(0)] public ushort vt;
      [FieldOffset(8)] public IntPtr ptr;
   }

   [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
   internal interface IPropertyStore
   {
      void GetCount(out uint count);
      void GetAt(uint index, out PROPERTYKEY key);
      void GetValue(ref PROPERTYKEY key, out PROPVARIANT value);
      void SetValue(ref PROPERTYKEY key, ref PROPVARIANT value);
      void Commit();
   }

   public static class Shortcut
   {
      private const ushort VT_LPWSTR = 31;
      private static PROPERTYKEY AppUserModelId = new PROPERTYKEY { fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), pid = 5 };

      [DllImport("ole32.dll")]
      private static extern int PropVariantClear(ref PROPVARIANT pv);

      public static void Create(string lnkPath, string target, string iconPath, int iconIndex, string description, string appId)
      {
         var link = (IShellLinkW)new CShellLink();
         try
         {
            link.SetPath(target);
            link.SetWorkingDirectory(Path.GetDirectoryName(target));
            link.SetIconLocation(iconPath, iconIndex);
            if (!string.IsNullOrEmpty(description)) link.SetDescription(description);

            if (!string.IsNullOrEmpty(appId))
            {
               var store = (IPropertyStore)link;
               var pv = new PROPVARIANT { vt = VT_LPWSTR, ptr = Marshal.StringToCoTaskMemUni(appId) };
               try
               {
                  store.SetValue(ref AppUserModelId, ref pv);
                  store.Commit();
               }
               finally { PropVariantClear(ref pv); }
            }

            ((IPersistFile)link).Save(lnkPath, true);
         }
         finally { Marshal.ReleaseComObject(link); }
      }

      // Returns (target, appId) for an existing .lnk; appId may be null.
      public static string[] Read(string lnkPath)
      {
         var link = (IShellLinkW)new CShellLink();
         try
         {
            ((IPersistFile)link).Load(lnkPath, 0);
            var sb = new StringBuilder(1024);
            link.GetPath(sb, sb.Capacity, IntPtr.Zero, 0);
            string appId = null;
            PROPVARIANT pv;
            ((IPropertyStore)link).GetValue(ref AppUserModelId, out pv);
            try { if (pv.vt == VT_LPWSTR) appId = Marshal.PtrToStringUni(pv.ptr); }
            finally { PropVariantClear(ref pv); }
            return new[] { sb.ToString(), appId };
         }
         finally { Marshal.ReleaseComObject(link); }
      }
   }
}
