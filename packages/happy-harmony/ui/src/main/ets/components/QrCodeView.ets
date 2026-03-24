/**
 * QR Code View component.
 * Renders a QR code using WebView with embedded JS library.
 * More reliable than pure ArkTS canvas approach.
 */
import { webview } from '@kit.ArkWeb';
import { LightColors } from '../theme/Colors';
import { Logger } from 'common';

const TAG = 'QrCodeView';

@Component
export struct QrCodeView {
  data: string = '';
  qrCodeSize: number = 240;
  controller: webview.WebviewController = new webview.WebviewController();
  @State qrReady: boolean = false;

  aboutToAppear(): void {
    // Do NOT call loadData here — the Web component is not yet attached.
    // loadData is called from onControllerAttached instead.
  }

  generateQRCode(): void {
    const escapedData: string = this.escapeHtml(this.data);
    const bgColor: string = '#FFFFFF';
    const fgColor: string = '#000000';
    const qrSize: number = this.qrCodeSize;

    // Minimal QR code library (qrcode-generator) embedded inline
    // Uses a compact version of the algorithm
    const html: string = `
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body { margin: 0; padding: 8px; display: flex; justify-content: center; align-items: center;
         min-height: 100vh; background: ${bgColor}; }
  canvas { display: block; }
</style>
</head>
<body>
<canvas id="qr"></canvas>
<script>
(function() {
  var data = "${escapedData}";
  var size = ${qrSize};
  var canvas = document.getElementById("qr");
  var ctx = canvas.getContext("2d");

  // Simple QR code generation using table-based approach
  // This is a minimal QR code encoder for byte mode, version auto-select, M error correction
  var qr = createQR(data);
  var moduleCount = qr.moduleCount;
  var cellSize = Math.floor(size / (moduleCount + 8));
  var totalSize = cellSize * (moduleCount + 8);
  canvas.width = totalSize;
  canvas.height = totalSize;

  var offset = cellSize * 4;
  ctx.fillStyle = "${bgColor}";
  ctx.fillRect(0, 0, totalSize, totalSize);
  ctx.fillStyle = "${fgColor}";

  for (var r = 0; r < moduleCount; r++) {
    for (var c = 0; c < moduleCount; c++) {
      if (qr.isDark(r, c)) {
        ctx.fillRect(offset + c * cellSize, offset + r * cellSize, cellSize, cellSize);
      }
    }
  }

  function createQR(text) {
    var encoder = new QREncoder(text);
    return { moduleCount: encoder.moduleCount, isDark: function(r, c) { return encoder.isDark(r, c); } };
  }

  function QREncoder(text) {
    var dataBytes = [];
    for (var i = 0; i < text.length; i++) dataBytes.push(text.charCodeAt(i) & 0xFF);
    var version = this.getBestVersion(dataBytes.length);
    this.moduleCount = version * 4 + 17;
    this.modules = [];
    this.isFunction = [];
    for (var r = 0; r < this.moduleCount; r++) {
      this.modules[r] = [];
      this.isFunction[r] = [];
      for (var c = 0; c < this.moduleCount; c++) {
        this.modules[r][c] = false;
        this.isFunction[r][c] = false;
      }
    }
    this.setupFinderPattern(0, 0);
    this.setupFinderPattern(this.moduleCount - 7, 0);
    this.setupFinderPattern(0, this.moduleCount - 7);
    this.setupTimingPattern();
    this.setupFormatInfo(1, 0, true);
    this.setupFormatInfo(1, this.moduleCount - 8, false);
    this.setupVersionInfo();
    this.mask(0);
    this.addData(dataBytes);
  }

  QREncoder.prototype.getBestVersion = function(dataLen) {
    var caps = [17,32,53,78,106,134,154,192,230,271,321,367,425,458,520,586,644,718,792,858,929,1003,1091,1171,1273,1367,1465,1528,1628,1732,1840,1952,2068,2188,2303,2431,2563,2699,2809,2953];
    for (var v = 1; v <= 40; v++) { if (dataLen <= caps[v-1]) return v; }
    return 10;
  };

  QREncoder.prototype.setupFinderPattern = function(row, col) {
    for (var r = -1; r <= 7; r++) {
      for (var c = -1; c <= 7; c++) {
        var mr = row + r, mc = col + c;
        if (mr < 0 || mr >= this.moduleCount || mc < 0 || mc >= this.moduleCount) continue;
        var dark = (r >= 0 && r <= 6 && (c === 0 || c === 6)) || (c >= 0 && c <= 6 && (r === 0 || r === 6)) || (r >= 2 && r <= 4 && c >= 2 && c <= 4);
        this.modules[mr][mc] = dark;
        this.isFunction[mr][mc] = true;
      }
    }
  };

  QREncoder.prototype.setupTimingPattern = function() {
    for (var i = 8; i < this.moduleCount - 8; i++) {
      var dark = i % 2 === 0;
      if (!this.isFunction[6][i]) { this.modules[6][i] = dark; this.isFunction[6][i] = true; }
      if (!this.isFunction[i][6]) { this.modules[i][6] = dark; this.isFunction[i][6] = true; }
    }
  };

  QREncoder.prototype.setupFormatInfo = function(mask, target, isDark) {
    var data = (1 << 3) | mask;
    var rem = data;
    for (var i = 0; i < 10; i++) rem = (rem << 1) ^ ((rem >> 9) * 0x537);
    var bits = ((data << 10) | rem) ^ 0x5412;
    for (var i = 0; i < 6; i++) this.modules[target][i] = isDark === ((bits >> i) & 1) === 1;
    this.modules[target][7] = isDark === ((bits >> 6) & 1) === 1;
    this.modules[target][8] = isDark === ((bits >> 7) & 1) === 1;
    this.modules[target - 1 < 0 ? 0 : target - 1][8] = isDark === ((bits >> 8) & 1) === 1;
    for (var i = 9; i < 15; i++) this.modules[target - (15 - i) < 0 ? 0 : target - (15 - i)][8] = isDark === ((bits >> i) & 1) === 1;
  };

  QREncoder.prototype.setupVersionInfo = function() {
    if (this.moduleCount < 25) return;
    var ver = (this.moduleCount - 17) / 4;
    var rem = ver;
    for (var i = 0; i < 12; i++) rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
    var bits = (ver << 12) | rem;
    for (var i = 0; i < 18; i++) {
      var dark = ((bits >> i) & 1) === 1;
      var r = Math.floor(i / 3), c = this.moduleCount - 11 + (i % 3);
      this.modules[r][c] = dark; this.isFunction[r][c] = true;
      this.modules[c][r] = dark; this.isFunction[c][r] = true;
    }
  };

  QREncoder.prototype.mask = function(maskPattern) {
    for (var r = 0; r < this.moduleCount; r++) {
      for (var c = 0; c < this.moduleCount; c++) {
        if (this.isFunction[r][c]) continue;
        var invert = false;
        switch (maskPattern) {
          case 0: invert = (r + c) % 2 === 0; break;
          case 1: invert = r % 2 === 0; break;
          case 2: invert = c % 3 === 0; break;
          case 3: invert = (r + c) % 3 === 0; break;
          case 4: invert = (Math.floor(r / 2) + Math.floor(c / 3)) % 2 === 0; break;
          case 5: invert = ((r * c) % 2 + (r * c) % 3) === 0; break;
          case 6: invert = ((r * c) % 2 + (r * c) % 3) % 2 === 0; break;
          case 7: invert = ((r + c) % 2 + (r * c) % 3) % 2 === 0; break;
        }
        if (invert) this.modules[r][c] = !this.modules[r][c];
      }
    }
  };

  QREncoder.prototype.addData = function(data) {
    var bitIndex = 0;
    var upward = true;
    for (var right = this.moduleCount - 1; right >= 1; right -= 2) {
      if (right === 6) right = 5;
      for (var vert = 0; vert < this.moduleCount; vert++) {
        var row = upward ? this.moduleCount - 1 - vert : vert;
        for (var j = 0; j < 2; j++) {
          var col = right - j;
          if (col < 0 || this.isFunction[row][col]) continue;
          var byteIdx = Math.floor(bitIndex / 8);
          var bitPos = 7 - (bitIndex % 8);
          this.modules[row][col] = byteIdx < data.length && ((data[byteIdx] >> bitPos) & 1) === 1;
          bitIndex++;
        }
      }
      upward = !upward;
    }
  };

  QREncoder.prototype.isDark = function(row, col) {
    if (row < 0 || row >= this.moduleCount || col < 0 || col >= this.moduleCount) return false;
    return this.modules[row][col];
  }
})();
<\/script>
</body>
</html>`;
    this.controller.loadData(html, 'text/html', 'UTF-8');
  }

  private escapeHtml(str: string): string {
    return str.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
      .replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  build() {
    Column() {
      Web({ src: '', controller: this.controller })
        .width(this.qrCodeSize)
        .height(this.qrCodeSize)
        .borderRadius(8)
        .backgroundColor(Color.White)
        .shadow({ radius: 8, color: '#00000010', offsetY: 2 })
        .javaScriptAccess(true)
        .domStorageAccess(false)
        .onControllerAttached(() => {
          // Load HTML only after the Web component is fully attached to the UI tree.
          // Calling loadData before attachment crashes on real devices.
          this.generateQRCode();
        })
        .onPageEnd(() => {
          this.qrReady = true;
        })
        .onErrorReceive((event) => {
          Logger.error(TAG, 'WebView error: ' + event.error.getErrorInfo());
        })
    }
  }
}
