/// MOBI实体类
/// 参考项目：io.legado.app.lib.mobi.entities
library;

/// PalmDoc头信息
class PalmDocHeader {
  final int compression;
  final int numTextRecords;
  final int recordSize;
  final int encryption;

  PalmDocHeader({
    required this.compression,
    required this.numTextRecords,
    required this.recordSize,
    required this.encryption,
  });
}

/// MOBI头信息
class MobiHeader {
  final String identifier;
  final int length;
  final int type;
  final int encoding;
  final int uid;
  final int version;
  final int titleOffset;
  final int titleLength;
  final int localeRegion;
  final int localeLanguage;
  final int resourceStart;
  final int huffcdic;
  final int numHuffcdic;
  final int exthFlag;
  final int trailingFlags;
  final int indx;
  final String title;
  final String language;

  MobiHeader({
    required this.identifier,
    required this.length,
    required this.type,
    required this.encoding,
    required this.uid,
    required this.version,
    required this.titleOffset,
    required this.titleLength,
    required this.localeRegion,
    required this.localeLanguage,
    required this.resourceStart,
    required this.huffcdic,
    required this.numHuffcdic,
    required this.exthFlag,
    required this.trailingFlags,
    required this.indx,
    required this.title,
    required this.language,
  });
}

/// MOBI元数据
class MobiMetadata {
  final String uid;
  final String title;
  final List<String> creators;
  final String publisher;
  final String language;
  final String date;
  final String description;
  final List<String> subjects;
  final String rights;

  MobiMetadata({
    required this.uid,
    required this.title,
    required this.creators,
    required this.publisher,
    required this.language,
    required this.date,
    required this.description,
    required this.subjects,
    required this.rights,
  });
}

/// MOBI章节信息
class MobiChapter {
  final String title;
  final int start;
  final int length;
  final String? href;

  MobiChapter({
    required this.title,
    required this.start,
    required this.length,
    this.href,
  });
}

/// NCX条目
class NCX {
  final int index;
  final int? offset;
  final int? size;
  final String label;
  final int? headingLevel;
  final List<int>? pos;
  final int? parent;
  final int? firstChild;
  final int? lastChild;
  List<NCX>? children;

  NCX({
    required this.index,
    this.offset,
    this.size,
    required this.label,
    this.headingLevel,
    this.pos,
    this.parent,
    this.firstChild,
    this.lastChild,
    this.children,
  });
}

/// 索引数据
class IndexData {
  final List<IndexEntry> table;
  final Map<int, String> cncx;

  IndexData({
    required this.table,
    required this.cncx,
  });
}

/// 索引条目
class IndexEntry {
  final String label;
  final List<IndexTag> tags;
  final Map<int, IndexTag> tagMap;

  IndexEntry({
    required this.label,
    required this.tags,
    required this.tagMap,
  });
}

/// 索引标签
class IndexTag {
  final int tagId;
  final List<int> tagValues;

  IndexTag({
    required this.tagId,
    required this.tagValues,
  });
}

/// INDX头
class IndxHeader {
  final String magic;
  final int length;
  final int type;
  final int idxt;
  final int numRecords;
  final int encoding;
  final int language;
  final int total;
  final int ordt;
  final int ligt;
  final int numLigt;
  final int numCncx;

  IndxHeader({
    required this.magic,
    required this.length,
    required this.type,
    required this.idxt,
    required this.numRecords,
    required this.encoding,
    required this.language,
    required this.total,
    required this.ordt,
    required this.ligt,
    required this.numLigt,
    required this.numCncx,
  });
}

/// TAGX头
class TagxHeader {
  final String magic;
  final int length;
  final int numControlBytes;

  TagxHeader({
    required this.magic,
    required this.length,
    required this.numControlBytes,
  });
}

/// TAGX标签
class TagxTag {
  final int tag;
  final int numValues;
  final int bitmask;
  final int controlByte;

  TagxTag({
    required this.tag,
    required this.numValues,
    required this.bitmask,
    required this.controlByte,
  });
}

/// PTAGX
class Ptagx {
  final int tag;
  final int? valueCount;
  final int? valueBytes;
  final int? tagValueCount;

  Ptagx({
    required this.tag,
    this.valueCount,
    this.valueBytes,
    this.tagValueCount,
  });
}

/// MOBI入口头
class MobiEntryHeaders {
  final PalmDocHeader palmdoc;
  final MobiHeader mobi;
  final Map<String, dynamic> exth;

  MobiEntryHeaders({
    required this.palmdoc,
    required this.mobi,
    required this.exth,
  });
}

/// EXTH记录类型
enum ExthRecordType {
  author(100),
  publisher(101),
  imprint(102),
  description(103),
  isbn(104),
  subject(105),
  publishingDate(106),
  review(107),
  contributor(108),
  rights(109),
  subjectCode(110),
  type(111),
  source(112),
  asin(113),
  versionNumber(114),
  sample(115),
  startReading(116),
  adult(117),
  retailPrice(118),
  retailPriceCurrency(119),
  kf8BoundaryOffset(121),
  fixedLayout(122),
  bookType(123),
  orientationLock(124),
  countOfResources(125),
  originalResolution(126),
  zeroGutter(127),
  zeroMargin(128),
  metadataResourceUri(129),
  coverOffset(201),
  thumbnailOffset(202),
  unknown(-1);

  final int value;
  const ExthRecordType(this.value);

  static ExthRecordType fromValue(int value) {
    return ExthRecordType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ExthRecordType.unknown,
    );
  }
}
