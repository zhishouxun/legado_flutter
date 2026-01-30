/// TTF 字体解析工具类
/// 参考项目：io.legado.app.model.analyzeRule.QueryTTF
///
/// 用于解析 TTF 字体文件，支持：
/// - Unicode 到字形索引（glyphId）的映射
/// - Unicode 到字形数据（glyph）的映射
/// - 字形数据到 Unicode 的反向映射
///
/// 主要用途：防盗版字体替换
/// 一些网站会使用自定义字体混淆文字显示，通过比较正确字体和错误字体的轮廓数据，
/// 可以反查出正确的 Unicode 字符。
library;

import 'dart:typed_data';

/// TTF 字体解析类
class QueryTTF {
  // ========== 内部数据结构 ==========

  /// 文件头
  final _Header _fileHeader = _Header();

  /// 数据表目录
  final Map<String, _Directory> _directories = {};

  /// name 表
  final _NameLayout _name = _NameLayout();

  /// head 表
  final _HeadLayout _head = _HeadLayout();

  /// maxp 表
  final _MaxpLayout _maxp = _MaxpLayout();

  /// cmap 表
  final _CmapLayout _cmap = _CmapLayout();

  /// loca 表数据
  List<int> _loca = [];

  /// glyf 表数据
  List<_GlyfLayout?> _glyfArray = [];

  // ========== 公开映射表 ==========

  /// Unicode -> 字形数据
  final Map<int, String?> unicodeToGlyph = {};

  /// 字形数据 -> Unicode
  final Map<String, int> glyphToUnicode = {};

  /// Unicode -> 字形索引
  final Map<int, int> unicodeToGlyphId = {};

  /// 构造函数
  /// [buffer] TTF 字体文件的二进制数据
  QueryTTF(Uint8List buffer) {
    final reader = _BufferReader(buffer, 0);

    // 读取文件头
    _fileHeader.sfntVersion = reader.readUInt32();
    _fileHeader.numTables = reader.readUInt16();
    _fileHeader.searchRange = reader.readUInt16();
    _fileHeader.entrySelector = reader.readUInt16();
    _fileHeader.rangeShift = reader.readUInt16();

    // 读取目录
    for (int i = 0; i < _fileHeader.numTables; i++) {
      final d = _Directory();
      d.tableTag = String.fromCharCodes(reader.readByteArray(4));
      d.checkSum = reader.readUInt32();
      d.offset = reader.readUInt32();
      d.length = reader.readUInt32();
      _directories[d.tableTag] = d;
    }

    // 解析各表
    _readNameTable(buffer);
    _readHeadTable(buffer);
    _readCmapTable(buffer);
    _readLocaTable(buffer);
    _readMaxpTable(buffer);
    _readGlyfTable(buffer);

    // 建立 Unicode & Glyph 映射表
    final glyfArrayLength = _glyfArray.length;
    for (final entry in unicodeToGlyphId.entries) {
      final key = entry.key;
      final val = entry.value;
      if (val >= glyfArrayLength) continue;
      final glyfString = getGlyfById(val);
      unicodeToGlyph[key] = glyfString;
      if (glyfString == null) continue;
      glyphToUnicode[glyfString] = key;
    }
  }

  /// 读取 name 表
  void _readNameTable(Uint8List buffer) {
    final dataTable = _directories['name'];
    if (dataTable == null) return;

    final reader = _BufferReader(buffer, dataTable.offset);
    _name.format = reader.readUInt16();
    _name.count = reader.readUInt16();
    _name.stringOffset = reader.readUInt16();

    for (int i = 0; i < _name.count; i++) {
      final record = _NameRecord();
      record.platformID = reader.readUInt16();
      record.encodingID = reader.readUInt16();
      record.languageID = reader.readUInt16();
      record.nameID = reader.readUInt16();
      record.length = reader.readUInt16();
      record.offset = reader.readUInt16();
      _name.records.add(record);
    }
  }

  /// 读取 head 表
  void _readHeadTable(Uint8List buffer) {
    final dataTable = _directories['head'];
    if (dataTable == null) return;

    final reader = _BufferReader(buffer, dataTable.offset);
    _head.majorVersion = reader.readUInt16();
    _head.minorVersion = reader.readUInt16();
    _head.fontRevision = reader.readUInt32();
    _head.checkSumAdjustment = reader.readUInt32();
    _head.magicNumber = reader.readUInt32();
    _head.flags = reader.readUInt16();
    _head.unitsPerEm = reader.readUInt16();
    _head.created = reader.readUInt64();
    _head.modified = reader.readUInt64();
    _head.xMin = reader.readInt16();
    _head.yMin = reader.readInt16();
    _head.xMax = reader.readInt16();
    _head.yMax = reader.readInt16();
    _head.macStyle = reader.readUInt16();
    _head.lowestRecPPEM = reader.readUInt16();
    _head.fontDirectionHint = reader.readInt16();
    _head.indexToLocFormat = reader.readInt16();
    _head.glyphDataFormat = reader.readInt16();
  }

  /// 读取 loca 表
  void _readLocaTable(Uint8List buffer) {
    final dataTable = _directories['loca'];
    if (dataTable == null) return;

    final reader = _BufferReader(buffer, dataTable.offset);
    if (_head.indexToLocFormat == 0) {
      _loca = reader.readUInt16Array(dataTable.length ~/ 2);
      // 当 loca 表数据长度为 Uint16 时，需要翻倍
      for (int i = 0; i < _loca.length; i++) {
        _loca[i] *= 2;
      }
    } else {
      _loca = reader.readInt32Array(dataTable.length ~/ 4);
    }
  }

  /// 读取 cmap 表
  void _readCmapTable(Uint8List buffer) {
    final dataTable = _directories['cmap'];
    if (dataTable == null) return;

    final reader = _BufferReader(buffer, dataTable.offset);
    _cmap.version = reader.readUInt16();
    _cmap.numTables = reader.readUInt16();

    // 读取 cmap 记录
    for (int i = 0; i < _cmap.numTables; i++) {
      final record = _CmapRecord();
      record.platformID = reader.readUInt16();
      record.encodingID = reader.readUInt16();
      record.offset = reader.readUInt32();
      _cmap.records.add(record);
    }

    // 解析 cmap 格式表
    for (final formatTable in _cmap.records) {
      final fmtOffset = formatTable.offset;
      if (_cmap.tables.containsKey(fmtOffset)) continue;

      reader.position = dataTable.offset + fmtOffset;

      final f = _CmapFormat();
      f.format = reader.readUInt16();
      f.length = reader.readUInt16();
      f.language = reader.readUInt16();

      switch (f.format) {
        case 0:
          // Format 0: Byte encoding table
          f.glyphIdArray = reader.readUInt8Array(f.length - 6);
          // 记录 unicode->glyphId 映射表
          for (int unicode = 0; unicode < f.glyphIdArray!.length; unicode++) {
            if (f.glyphIdArray![unicode] == 0) continue;
            unicodeToGlyphId[unicode] = f.glyphIdArray![unicode];
          }
          break;

        case 4:
          // Format 4: Segment mapping to delta values
          f.segCountX2 = reader.readUInt16();
          final segCount = f.segCountX2! ~/ 2;
          f.searchRange = reader.readUInt16();
          f.entrySelector = reader.readUInt16();
          f.rangeShift = reader.readUInt16();
          f.endCode = reader.readUInt16Array(segCount);
          f.reservedPad = reader.readUInt16();
          f.startCode = reader.readUInt16Array(segCount);
          f.idDelta = reader.readInt16Array(segCount);
          f.idRangeOffsets = reader.readUInt16Array(segCount);

          // 字形索引数组
          final glyphIdArrayLength = (f.length - 16 - (segCount * 8)) ~/ 2;
          f.glyphIdArray = reader.readUInt16Array(glyphIdArrayLength);

          // 记录 unicode->glyphId 映射表
          for (int segmentIndex = 0; segmentIndex < segCount; segmentIndex++) {
            final unicodeStart = f.startCode![segmentIndex];
            final unicodeEnd = f.endCode![segmentIndex];
            final idDelta = f.idDelta![segmentIndex];
            final idRangeOffset = f.idRangeOffsets![segmentIndex];

            for (int unicode = unicodeStart; unicode <= unicodeEnd; unicode++) {
              int glyphId = 0;
              if (idRangeOffset == 0) {
                glyphId = (unicode + idDelta) & 0xFFFF;
              } else {
                final gIndex = (idRangeOffset ~/ 2) +
                    unicode -
                    unicodeStart +
                    segmentIndex -
                    segCount;
                if (gIndex < glyphIdArrayLength) {
                  glyphId = f.glyphIdArray![gIndex] + idDelta;
                }
              }
              if (glyphId == 0) continue;
              unicodeToGlyphId[unicode] = glyphId;
            }
          }
          break;

        case 6:
          // Format 6: Trimmed table mapping
          f.firstCode = reader.readUInt16();
          f.entryCount = reader.readUInt16();
          f.glyphIdArray = reader.readUInt16Array(f.entryCount!);

          // 记录 unicode->glyphId 映射表
          int unicodeIndex = f.firstCode!;
          for (int gIndex = 0; gIndex < f.entryCount!; gIndex++) {
            unicodeToGlyphId[unicodeIndex] = f.glyphIdArray![gIndex];
            unicodeIndex++;
          }
          break;
      }

      _cmap.tables[fmtOffset] = f;
    }
  }

  /// 读取 maxp 表
  void _readMaxpTable(Uint8List buffer) {
    final dataTable = _directories['maxp'];
    if (dataTable == null) return;

    final reader = _BufferReader(buffer, dataTable.offset);
    _maxp.version = reader.readUInt32();
    _maxp.numGlyphs = reader.readUInt16();
    _maxp.maxPoints = reader.readUInt16();
    _maxp.maxContours = reader.readUInt16();
    _maxp.maxCompositePoints = reader.readUInt16();
    _maxp.maxCompositeContours = reader.readUInt16();
    _maxp.maxZones = reader.readUInt16();
    _maxp.maxTwilightPoints = reader.readUInt16();
    _maxp.maxStorage = reader.readUInt16();
    _maxp.maxFunctionDefs = reader.readUInt16();
    _maxp.maxInstructionDefs = reader.readUInt16();
    _maxp.maxStackElements = reader.readUInt16();
    _maxp.maxSizeOfInstructions = reader.readUInt16();
    _maxp.maxComponentElements = reader.readUInt16();
    _maxp.maxComponentDepth = reader.readUInt16();
  }

  /// 读取 glyf 表
  void _readGlyfTable(Uint8List buffer) {
    final dataTable = _directories['glyf'];
    if (dataTable == null) return;

    final glyfCount = _maxp.numGlyphs;
    _glyfArray = List.filled(glyfCount, null);

    final reader = _BufferReader(buffer, 0);

    for (int index = 0; index < glyfCount; index++) {
      if (index + 1 >= _loca.length) continue;
      if (_loca[index] == _loca[index + 1]) continue; // 字形不存在

      final offset = dataTable.offset + _loca[index];
      reader.position = offset;

      final glyph = _GlyfLayout();
      glyph.numberOfContours = reader.readInt16();

      // 如果字形轮廓数大于最大轮廓数，则无效
      if (glyph.numberOfContours > _maxp.maxContours) continue;

      glyph.xMin = reader.readInt16();
      glyph.yMin = reader.readInt16();
      glyph.xMax = reader.readInt16();
      glyph.yMax = reader.readInt16();

      // 轮廓数为0时，不需要解析轮廓数据
      if (glyph.numberOfContours == 0) continue;

      if (glyph.numberOfContours > 0) {
        // 简单轮廓
        glyph.glyphSimple = _GlyphTableBySimple();
        glyph.glyphSimple!.endPtsOfContours =
            reader.readUInt16Array(glyph.numberOfContours);
        glyph.glyphSimple!.instructionLength = reader.readUInt16();
        glyph.glyphSimple!.instructions =
            reader.readUInt8Array(glyph.glyphSimple!.instructionLength);

        final flagLength = glyph.glyphSimple!.endPtsOfContours[
                glyph.glyphSimple!.endPtsOfContours.length - 1] +
            1;

        // 获取轮廓点描述标志
        glyph.glyphSimple!.flags = List.filled(flagLength, 0);
        for (int n = 0; n < flagLength; n++) {
          final glyphSimpleFlag = reader.readUInt8();
          glyph.glyphSimple!.flags[n] = glyphSimpleFlag;
          if ((glyphSimpleFlag & 0x08) == 0x08) {
            final repeatCount = reader.readUInt8();
            for (int m = 0; m < repeatCount; m++) {
              n++;
              if (n < flagLength) {
                glyph.glyphSimple!.flags[n] = glyphSimpleFlag;
              }
            }
          }
        }

        // 获取轮廓点描述 x 轴相对值
        glyph.glyphSimple!.xCoordinates = List.filled(flagLength, 0);
        for (int n = 0; n < flagLength; n++) {
          switch (glyph.glyphSimple!.flags[n] & 0x12) {
            case 0x02:
              glyph.glyphSimple!.xCoordinates[n] = -1 * reader.readUInt8();
              break;
            case 0x12:
              glyph.glyphSimple!.xCoordinates[n] = reader.readUInt8();
              break;
            case 0x10:
              glyph.glyphSimple!.xCoordinates[n] = 0;
              break;
            case 0x00:
              glyph.glyphSimple!.xCoordinates[n] = reader.readInt16();
              break;
          }
        }

        // 获取轮廓点描述 y 轴相对值
        glyph.glyphSimple!.yCoordinates = List.filled(flagLength, 0);
        for (int n = 0; n < flagLength; n++) {
          switch (glyph.glyphSimple!.flags[n] & 0x24) {
            case 0x04:
              glyph.glyphSimple!.yCoordinates[n] = -1 * reader.readUInt8();
              break;
            case 0x24:
              glyph.glyphSimple!.yCoordinates[n] = reader.readUInt8();
              break;
            case 0x20:
              glyph.glyphSimple!.yCoordinates[n] = 0;
              break;
            case 0x00:
              glyph.glyphSimple!.yCoordinates[n] = reader.readInt16();
              break;
          }
        }
      } else {
        // 复合轮廓
        glyph.glyphComponent = [];
        while (true) {
          final component = _GlyphTableComponent();
          component.flags = reader.readUInt16();
          component.glyphIndex = reader.readUInt16();

          switch (component.flags & 0x03) {
            case 0x00:
              component.argument1 = reader.readUInt8();
              component.argument2 = reader.readUInt8();
              break;
            case 0x02:
              component.argument1 = reader.readInt8();
              component.argument2 = reader.readInt8();
              break;
            case 0x01:
              component.argument1 = reader.readUInt16();
              component.argument2 = reader.readUInt16();
              break;
            case 0x03:
              component.argument1 = reader.readInt16();
              component.argument2 = reader.readInt16();
              break;
          }

          switch (component.flags & 0xC8) {
            case 0x08:
              // 有单一比例
              component.xScale = reader.readUInt16() / 16384.0;
              component.yScale = component.xScale;
              break;
            case 0x40:
              // 有 X 和 Y 的独立比例
              component.xScale = reader.readUInt16() / 16384.0;
              component.yScale = reader.readUInt16() / 16384.0;
              break;
            case 0x80:
              // 有 2x2 变换矩阵
              component.xScale = reader.readUInt16() / 16384.0;
              component.scale01 = reader.readUInt16() / 16384.0;
              component.scale10 = reader.readUInt16() / 16384.0;
              component.yScale = reader.readUInt16() / 16384.0;
              break;
          }

          glyph.glyphComponent!.add(component);

          // 检查是否还有更多组件
          if ((component.flags & 0x20) == 0) break;
        }
      }

      _glyfArray[index] = glyph;
    }
  }

  /// 使用轮廓索引获取轮廓数据字符串
  String? getGlyfById(int glyfId) {
    if (glyfId < 0 || glyfId >= _glyfArray.length) return null;
    final glyph = _glyfArray[glyfId];
    if (glyph == null) return null;

    if (glyph.numberOfContours >= 0) {
      // 简单字形
      if (glyph.glyphSimple == null) return null;
      final dataCount = glyph.glyphSimple!.flags.length;
      final coordinates = <String>[];
      for (int i = 0; i < dataCount; i++) {
        coordinates.add(
            '${glyph.glyphSimple!.xCoordinates[i]},${glyph.glyphSimple!.yCoordinates[i]}');
      }
      return coordinates.join('|');
    } else {
      // 复合字形
      if (glyph.glyphComponent == null) return null;
      final glyphIdList = <String>[];
      for (final g in glyph.glyphComponent!) {
        glyphIdList.add('{flags:${g.flags},'
            'glyphIndex:${g.glyphIndex},'
            'arg1:${g.argument1},'
            'arg2:${g.argument2},'
            'xScale:${g.xScale},'
            'scale01:${g.scale01},'
            'scale10:${g.scale10},'
            'yScale:${g.yScale}}');
      }
      return '[${glyphIdList.join(',')}]';
    }
  }

  /// 使用 Unicode 值查询轮廓索引
  int getGlyfIdByUnicode(int unicode) {
    return unicodeToGlyphId[unicode] ?? 0;
  }

  /// 使用 Unicode 值查询轮廓数据
  String? getGlyfByUnicode(int unicode) {
    return unicodeToGlyph[unicode];
  }

  /// 使用轮廓数据反查 Unicode 值
  int getUnicodeByGlyf(String? glyph) {
    if (glyph == null) return 0;
    return glyphToUnicode[glyph] ?? 0;
  }

  /// Unicode 空白字符判断
  bool isBlankUnicode(int unicode) {
    switch (unicode) {
      case 0x0009: // 水平制表符
      case 0x0020: // 空格
      case 0x00A0: // 不中断空格
      case 0x2002: // En 空格
      case 0x2003: // Em 空格
      case 0x2007: // 刚性空格
      case 0x200A: // 发音修饰字母的连字符
      case 0x200B: // 零宽空格
      case 0x200C: // 零宽不连字
      case 0x200D: // 零宽连字
      case 0x202F: // 狭窄不中断空格
      case 0x205F: // 中等数学空格
        return true;
      default:
        return false;
    }
  }
}

// ========== 内部数据结构 ==========

/// 字节缓冲区读取器
class _BufferReader {
  final ByteData _data;
  int position;

  _BufferReader(Uint8List buffer, this.position)
      : _data = ByteData.view(buffer.buffer);

  int readUInt64() {
    final value = _data.getUint64(position, Endian.big);
    position += 8;
    return value;
  }

  int readUInt32() {
    final value = _data.getUint32(position, Endian.big);
    position += 4;
    return value;
  }

  int readInt32() {
    final value = _data.getInt32(position, Endian.big);
    position += 4;
    return value;
  }

  int readUInt16() {
    final value = _data.getUint16(position, Endian.big);
    position += 2;
    return value;
  }

  int readInt16() {
    final value = _data.getInt16(position, Endian.big);
    position += 2;
    return value;
  }

  int readUInt8() {
    final value = _data.getUint8(position);
    position += 1;
    return value;
  }

  int readInt8() {
    final value = _data.getInt8(position);
    position += 1;
    return value;
  }

  Uint8List readByteArray(int len) {
    final result = Uint8List.fromList(_data.buffer.asUint8List(position, len));
    position += len;
    return result;
  }

  List<int> readUInt8Array(int len) {
    final result = <int>[];
    for (int i = 0; i < len; i++) {
      result.add(readUInt8());
    }
    return result;
  }

  List<int> readInt16Array(int len) {
    final result = <int>[];
    for (int i = 0; i < len; i++) {
      result.add(readInt16());
    }
    return result;
  }

  List<int> readUInt16Array(int len) {
    final result = <int>[];
    for (int i = 0; i < len; i++) {
      result.add(readUInt16());
    }
    return result;
  }

  List<int> readInt32Array(int len) {
    final result = <int>[];
    for (int i = 0; i < len; i++) {
      result.add(readInt32());
    }
    return result;
  }
}

/// 文件头
class _Header {
  int sfntVersion = 0;
  int numTables = 0;
  int searchRange = 0;
  int entrySelector = 0;
  int rangeShift = 0;
}

/// 数据表目录
class _Directory {
  String tableTag = '';
  int checkSum = 0;
  int offset = 0;
  int length = 0;
}

/// name 表结构
class _NameLayout {
  int format = 0;
  int count = 0;
  int stringOffset = 0;
  List<_NameRecord> records = [];
}

/// name 记录
class _NameRecord {
  int platformID = 0;
  int encodingID = 0;
  int languageID = 0;
  int nameID = 0;
  int length = 0;
  int offset = 0;
}

/// head 表结构
class _HeadLayout {
  int majorVersion = 0;
  int minorVersion = 0;
  int fontRevision = 0;
  int checkSumAdjustment = 0;
  int magicNumber = 0;
  int flags = 0;
  int unitsPerEm = 0;
  int created = 0;
  int modified = 0;
  int xMin = 0;
  int yMin = 0;
  int xMax = 0;
  int yMax = 0;
  int macStyle = 0;
  int lowestRecPPEM = 0;
  int fontDirectionHint = 0;
  int indexToLocFormat = 0;
  int glyphDataFormat = 0;
}

/// maxp 表结构
class _MaxpLayout {
  int version = 0;
  int numGlyphs = 0;
  int maxPoints = 0;
  int maxContours = 0;
  int maxCompositePoints = 0;
  int maxCompositeContours = 0;
  int maxZones = 0;
  int maxTwilightPoints = 0;
  int maxStorage = 0;
  int maxFunctionDefs = 0;
  int maxInstructionDefs = 0;
  int maxStackElements = 0;
  int maxSizeOfInstructions = 0;
  int maxComponentElements = 0;
  int maxComponentDepth = 0;
}

/// cmap 表结构
class _CmapLayout {
  int version = 0;
  int numTables = 0;
  List<_CmapRecord> records = [];
  Map<int, _CmapFormat> tables = {};
}

/// cmap 记录
class _CmapRecord {
  int platformID = 0;
  int encodingID = 0;
  int offset = 0;
}

/// cmap 格式表
class _CmapFormat {
  int format = 0;
  int length = 0;
  int language = 0;
  List<int>? subHeaderKeys;
  List<int>? subHeaders;
  int? segCountX2;
  int? searchRange;
  int? entrySelector;
  int? rangeShift;
  List<int>? endCode;
  int? reservedPad;
  List<int>? startCode;
  List<int>? idDelta;
  List<int>? idRangeOffsets;
  int? firstCode;
  int? entryCount;
  List<int>? glyphIdArray;
}

/// glyf 表结构
class _GlyfLayout {
  int numberOfContours = 0;
  int xMin = 0;
  int yMin = 0;
  int xMax = 0;
  int yMax = 0;
  _GlyphTableBySimple? glyphSimple;
  List<_GlyphTableComponent>? glyphComponent;
}

/// 简单字形数据表
class _GlyphTableBySimple {
  List<int> endPtsOfContours = [];
  int instructionLength = 0;
  List<int> instructions = [];
  List<int> flags = [];
  List<int> xCoordinates = [];
  List<int> yCoordinates = [];
}

/// 复合字形数据表
class _GlyphTableComponent {
  int flags = 0;
  int glyphIndex = 0;
  int argument1 = 0;
  int argument2 = 0;
  double xScale = 0.0;
  double scale01 = 0.0;
  double scale10 = 0.0;
  double yScale = 0.0;
}
