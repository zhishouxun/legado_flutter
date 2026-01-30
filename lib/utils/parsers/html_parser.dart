import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:xpath_selector/xpath_selector.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';
import 'package:xml/xml.dart' as xml;
import '../app_log.dart';

class HtmlParser {
  /// 解析 HTML 字符串
  static html_dom.Document parse(String html) {
    return html_parser.parse(html);
  }

  /// 使用 CSS 选择器获取元素
  static List<html_dom.Element> selectElements(
    dynamic container, // 可以是 Document 或 Element
    String selector,
  ) {
    if (container is html_dom.Document) {
      return container.querySelectorAll(selector);
    } else if (container is html_dom.Element) {
      return container.querySelectorAll(selector);
    }
    return [];
  }

  /// 使用 CSS 选择器获取单个元素
  static html_dom.Element? selectElement(
    dynamic container, // 可以是 Document 或 Element
    String selector,
  ) {
    if (container is html_dom.Document) {
      return container.querySelector(selector);
    } else if (container is html_dom.Element) {
      return container.querySelector(selector);
    }
    return null;
  }

  /// 使用 XPath 获取元素
  /// 参考项目：AnalyzeByXPath.getElements
  /// 使用 xpath_selector 包执行 XPath 查询
  /// 参考项目：JXDocument.create(html) 和 selN(xpath)
  static List<XPathNode> selectXPath(
    html_dom.Document document,
    String xpath,
  ) {
    try {
      if (xpath.isEmpty) return [];

      // 参考项目：处理不完整的HTML片段（如 </td>, </tr> 等）
      String html = document.outerHtml;

      // 增强不完整 HTML 片段的容错处理
      html = _fixIncompleteHtml(html);

      // 参考项目：处理 XML 格式
      // kotlin.runCatching {
      //   if (html1.trim().startsWith("<?xml", true)) {
      //     return JXDocument.create(Jsoup.parse(html1, Parser.xmlParser()))
      //   }
      // }
      // 实现 XML 格式检测和处理
      final trimmedHtml = html.trim();
      final isXml = trimmedHtml.toLowerCase().startsWith('<?xml');

      if (isXml) {
        try {
          // 尝试使用 xml 包解析 XML，验证 XML 格式是否正确
          // 参考项目使用 JSoup 的 Parser.xmlParser()，这里使用 xml 包验证
          // 注意：HtmlXPath.html() 可能已经支持 XML 格式，所以这里主要是验证
          xml.XmlDocument.parse(html);
          AppLog.instance
              .putDebug('HtmlParser.selectXPath: 检测到 XML 格式，已验证 XML 格式正确');
        } catch (e) {
          AppLog.instance.putDebug(
              'HtmlParser.selectXPath: XML 解析失败，尝试作为 HTML 处理',
              error: e);
        }
      }

      // 使用 xpath_selector 包执行 XPath 查询
      // 参考项目：JXDocument.create(html) 和 selN(xpath)
      //
      // xpath_selector 3.0.2 包的 API：
      // 根据文档，需要使用 HtmlXPath.html() 方法创建 XPath 查询对象
      // 然后使用 query() 方法执行查询，返回 XPathResult
      // XPathResult 有 nodes 属性，返回 List<XPathNode>
      //
      // 参考项目的实现逻辑：
      // 1. JXDocument.create(html) 创建文档对象
      // 2. selN(xpath) 执行查询，返回 List<JXNode>
      // 3. JXNode.asString() 获取节点的字符串表示（自动处理属性和文本）
      //
      // 尝试实现 XPath 查询
      try {
        // 使用 HtmlXPath.html() 创建 XPath 查询对象
        // 参考项目：JXDocument.create(html) 和 selN(xpath)
        // 注意：HtmlXPath.html() 可能支持 XML 格式，如果不支持，会抛出异常
        final xpathQuery = HtmlXPath.html(html);

        // 执行 XPath 查询
        final result = xpathQuery.query(xpath);

        // 从结果中获取节点列表
        // XPathResult 有 nodes 属性，返回 List<XPathNode>
        return result.nodes;
      } catch (e) {
        // XPath 查询失败，记录日志并返回空列表
        AppLog.instance
            .putDebug('HtmlParser.selectXPath: XPath 查询失败', error: e);
        return [];
      }
    } catch (e) {
      // XPath 解析失败，记录日志并返回空列表
      AppLog.instance.putDebug('HtmlParser.selectXPath: XPath 解析失败', error: e);
      return [];
    }
  }

  /// 修复不完整的 HTML 片段
  /// 参考项目：JSoup 对不完整 HTML 片段的容错处理
  static String _fixIncompleteHtml(String html) {
    if (html.isEmpty) return html;

    // 处理不完整的表格元素
    if (html.endsWith('</td>')) {
      html = '<tr>$html</tr>';
    }
    if (html.endsWith('</tr>') || html.endsWith('</tbody>')) {
      html = '<table>$html</table>';
    }

    // 处理不完整的列表元素
    if (html.endsWith('</li>')) {
      html = '<ul>$html</ul>';
    }

    // 处理不完整的 div 元素（如果只有结束标签）
    if (html.startsWith('</div>')) {
      html = '<div>$html</div>';
    }

    // 处理不完整的 p 元素
    if (html.startsWith('</p>')) {
      html = '<p>$html</p>';
    }

    return html;
  }

  /// 获取 XPath 节点的字符串表示（参考项目：JXNode.asString()）
  /// 参考项目：JXNode.asString() 会自动处理属性和文本
  /// 如果节点是属性节点，返回属性值；如果是元素节点，返回文本内容
  ///
  /// 实现逻辑（参考 JXNode.asString()）：
  /// 1. 如果是属性节点，返回属性值
  /// 2. 如果是元素节点，返回文本内容（包括所有子元素的文本）
  /// 3. 如果是文本节点，返回文本内容
  static String? getXPathNodeString(XPathNode node) {
    try {
      // xpath_selector 包中，XPathNode 的行为：
      // - node.text: 对于属性节点返回属性值，对于元素节点返回所有文本内容
      // - node.attributes: 属性 Map（对于元素节点）
      // - node.toString(): 字符串表示

      // 方式1: 尝试直接获取 text（最直接的方式，应该已经实现了类似 JXNode.asString() 的逻辑）
      // 参考项目：JXNode.asString() 对于属性节点返回属性值，对于元素节点返回文本内容
      try {
        final text = node.text;
        // text 可能为空字符串，这是有效的（节点可能没有文本内容）
        if (text != null) {
          return text;
        }
      } catch (e) {
        // text 属性不存在或访问失败，继续尝试其他方式
        AppLog.instance.putDebug(
            'HtmlParser.getXPathNodeString: 无法获取 node.text',
            error: e);
      }

      // 方式2: 尝试 toString() 方法
      // 注意：toString() 可能返回节点的字符串表示，但不一定是文本内容
      try {
        final str = node.toString();
        if (str.isNotEmpty) {
          // 如果 toString() 返回的内容看起来像文本（不包含 HTML 标签），则使用它
          if (!str.contains('<') || !str.contains('>')) {
            return str;
          }
        }
      } catch (e) {
        // toString() 失败
        AppLog.instance
            .putDebug('HtmlParser.getXPathNodeString: toString() 失败', error: e);
      }

      // 方式3: 如果节点是元素节点但没有文本内容，返回空字符串
      // 参考项目：JXNode.asString() 对于没有文本的元素节点返回空字符串
      try {
        final attrs = node.attributes;
        // 如果节点有属性但没有文本，说明是元素节点但没有文本内容
        if (attrs.isNotEmpty) {
          return '';
        }
      } catch (e) {
        // attributes 属性不存在，忽略
      }

      // 如果所有方式都失败，返回空字符串（而不是 null）
      // 参考项目：JXNode.asString() 不会返回 null
      return '';
    } catch (e) {
      AppLog.instance
          .putDebug('HtmlParser.getXPathNodeString: 获取节点字符串表示失败', error: e);
      return '';
    }
  }

  /// 获取 XPath 节点的属性值
  /// 参考项目：从 XPath 表达式中提取属性名，然后获取属性值
  /// 注意：如果 XPath 查询的是属性节点（如 //a/@href），node.text 就是属性值
  /// 如果 XPath 查询的是元素节点（如 //a），需要从 node.attributes 中获取属性值
  static String? getXPathNodeAttribute(XPathNode node, String attributeName) {
    try {
      // 方式1: 如果节点本身就是属性节点，text 就是属性值
      // 这通常发生在 XPath 表达式是 @attributeName 时
      // 参考项目：JXNode.asString() 对于属性节点返回属性值
      try {
        final text = node.text;
        if (text != null && text.isNotEmpty) {
          // 如果节点是属性节点，text 就是属性值
          // 但需要验证属性名是否匹配（如果可能的话）
          return text;
        }
      } catch (e) {
        // text 属性不存在或访问失败，继续尝试其他方式
      }

      // 方式2: 如果节点是元素节点，尝试从 attributes Map 中获取属性值
      // 参考项目：从元素节点的属性 Map 中获取指定属性的值
      try {
        final attrs = node.attributes;
        if (attrs.isNotEmpty) {
          // 尝试直接获取属性值
          final attrValue = attrs[attributeName];
          if (attrValue != null) {
            return attrValue.toString();
          }

          // 尝试不区分大小写的匹配（某些情况下属性名可能大小写不同）
          for (final entry in attrs.entries) {
            final key = entry.key.toString();
            if (key.toLowerCase() == attributeName.toLowerCase()) {
              return entry.value.toString();
            }
          }
        }
      } catch (e) {
        // attributes 属性不存在或访问失败
        AppLog.instance.putDebug(
            'HtmlParser.getXPathNodeAttribute: 无法获取 attributes',
            error: e);
      }

      // 方式3: 尝试从 node 中提取 html_dom.Element，然后获取属性
      // 这是最可靠的方式，因为可以直接访问 Element.attributes
      try {
        final dynamic nodeDynamic = node;
        final element = nodeDynamic.element;
        if (element != null && element is html_dom.Element) {
          final attrValue = element.attributes[attributeName];
          if (attrValue != null) {
            return attrValue;
          }
          // 尝试不区分大小写的匹配
          for (final entry in element.attributes.entries) {
            final key = entry.key.toString();
            if (key.toLowerCase() == attributeName.toLowerCase()) {
              return entry.value;
            }
          }
        }
      } catch (e) {
        // element 属性不存在或类型不匹配
      }

      return null;
    } catch (e) {
      AppLog.instance
          .putDebug('HtmlParser.getXPathNodeAttribute: 获取属性值失败', error: e);
      return null;
    }
  }

  /// 获取元素的文本内容
  /// 参考项目：JSoup 的 element.text() 会自动将 <br /> 转换为换行符
  /// Dart 的 html 包的 text 属性可能不会自动处理 <br />，需要手动处理
  static String? getText(html_dom.Element? element) {
    if (element == null) return null;
    
    // 参考项目：JSoup 的 element.text() 会自动将 <br /> 转换为换行符
    // Dart 的 html 包的 text 属性可能不会自动处理，需要手动遍历 DOM 树
    final buffer = StringBuffer();
    _extractTextWithBr(element, buffer);
    final text = buffer.toString();
    
    // 清理多余的换行符（连续多个换行符合并为一个）
    // 但保留单个换行符，因为 <br /> 应该产生换行
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }
  
  /// 递归提取文本内容，遇到 <br /> 标签时插入换行符
  /// 参考项目：JSoup 的 element.text() 行为
  /// JSoup 的 text() 方法会自动将 <br /> 转换为换行符
  static void _extractTextWithBr(html_dom.Node node, StringBuffer buffer) {
    if (node is html_dom.Text) {
      final text = node.text;
      if (text.isNotEmpty) {
        buffer.write(text);
      }
    } else if (node is html_dom.Element) {
      final tagName = node.localName?.toLowerCase() ?? '';
      
      // 检查是否是 <br /> 标签（包括 <br>, <br/>, <BR>, <BR/> 等）
      if (tagName == 'br') {
        buffer.write('\n');
      } else {
        // 递归处理所有子节点
        for (final child in node.nodes) {
          _extractTextWithBr(child, buffer);
        }
      }
    }
  }

  /// 获取元素的属性值
  static String? getAttribute(html_dom.Element? element, String attribute) {
    return element?.attributes[attribute];
  }

  /// 获取元素的 HTML 内容（innerHTML，不包含元素本身的标签）
  static String? getHtml(html_dom.Element? element) {
    return element?.innerHtml;
  }

  /// 获取元素的完整 HTML（outerHTML，包含元素本身的标签）
  static String? getOuterHtml(html_dom.Element? element) {
    if (element == null) return null;
    // 使用 outerHtml 属性获取包含标签的完整HTML
    return element.outerHtml;
  }

  /// 获取 XPath 节点的 outerHTML（完整HTML，包含元素本身的标签）
  /// 参考项目：JXNode.asString() 在需要返回HTML时返回outerHTML
  /// 注意：xpath_selector 包中的 XPathNode 可能没有直接的 outerHtml 属性
  /// 需要尝试从 node 中提取对应的 html_dom.Element 来获取 outerHtml
  static String? getXPathNodeOuterHtml(XPathNode node) {
    try {
      // 方式1: 尝试直接获取 outerHtml 属性（如果存在）
      // 某些 XPathNode 实现可能有 outerHtml 属性
      try {
        final dynamic nodeDynamic = node;
        final outerHtml = nodeDynamic.outerHtml;
        if (outerHtml != null) {
          final htmlStr = outerHtml.toString();
          if (htmlStr.isNotEmpty) {
            return htmlStr;
          }
        }
      } catch (e) {
        // outerHtml 属性不存在，继续尝试其他方式
      }

      // 方式2: 尝试从 node 中提取 html_dom.Element
      // xpath_selector_html_parser 包中的 XPathNode 可能包含对原始 Element 的引用
      // 这是最可靠的方式，因为可以直接获取 Element.outerHtml
      try {
        final dynamic nodeDynamic = node;
        final element = nodeDynamic.element;
        if (element != null) {
          // 检查 element 是否是 html_dom.Element
          if (element is html_dom.Element) {
            return element.outerHtml;
          }
          // 尝试转换
          final htmlElement = element as html_dom.Element?;
          if (htmlElement != null) {
            return htmlElement.outerHtml;
          }
        }
      } catch (e) {
        // element 属性不存在或类型不匹配
      }

      // 方式3: 尝试获取 node 的 node 属性（某些实现可能使用这个名称）
      try {
        final dynamic nodeDynamic = node;
        final nodeValue = nodeDynamic.node;
        if (nodeValue != null && nodeValue is html_dom.Element) {
          return nodeValue.outerHtml;
        }
      } catch (e) {
        // node 属性不存在
      }

      // 方式4: 尝试使用 toString() 方法（可能返回 HTML 表示）
      // 注意：toString() 可能返回 HTML，但也可能只返回文本内容
      try {
        final str = node.toString();
        // 如果 toString() 返回的内容看起来像 HTML（包含标签），则使用它
        if (str.isNotEmpty && str.contains('<') && str.contains('>')) {
          // 进一步验证：检查是否包含完整的 HTML 标签结构
          // 简单的检查：是否包含开始和结束标签
          if (str.contains('</')) {
            return str;
          }
          // 如果只有开始标签，也可能是有用的 HTML
          if (RegExp(r'<[^>]+>').hasMatch(str)) {
            return str;
          }
        }
      } catch (e) {
        // toString() 失败
      }

      // 方式5: 如果节点是属性节点，返回属性值的 HTML 转义形式
      // 参考项目：对于属性节点，JXNode.asString() 返回属性值
      // 但这里我们需要返回 HTML，所以返回属性值的 HTML 表示
      try {
        final text = node.text;
        final attrs = node.attributes;
        // 如果节点有 text 但没有 attributes，可能是属性节点或文本节点
        if (text != null &&
            text.isNotEmpty &&
            (attrs.isEmpty || attrs.isEmpty)) {
          // 对于属性节点，返回属性值的 HTML 转义形式
          // 但这不是真正的 outerHTML，所以只作为最后的尝试
          return text;
        }
      } catch (e) {
        // 获取 text 或 attributes 失败
      }

      // 方式6: 如果以上都失败，记录日志并返回 null
      // 参考项目：JXNode.asString() 在需要返回 HTML 时应该返回 outerHTML
      // 如果无法获取，返回 null 表示失败
      AppLog.instance
          .putDebug('HtmlParser.getXPathNodeOuterHtml: 无法获取节点的 outerHTML');
      return null;
    } catch (e) {
      AppLog.instance.putDebug(
          'HtmlParser.getXPathNodeOuterHtml: 获取 outerHTML 失败',
          error: e);
      return null;
    }
  }

  /// 获取元素的 HTML 内容（移除script和style标签）
  /// 参考项目：AnalyzeByJSoup.getResultLast - "html" 分支
  /// elements.select("script").remove() 和 elements.select("style").remove() 后再返回 outerHtml()
  static String? getHtmlWithoutScriptAndStyle(html_dom.Element? element) {
    if (element == null) return null;

    try {
      // 克隆元素以避免修改原始元素
      final cloned = element.clone(true);

      // 移除所有 script 标签
      final scripts = cloned.querySelectorAll('script');
      for (final script in scripts) {
        script.remove();
      }

      // 移除所有 style 标签
      final styles = cloned.querySelectorAll('style');
      for (final style in styles) {
        style.remove();
      }

      return cloned.outerHtml;
    } catch (e) {
      // 如果克隆失败，返回原始outerHtml
      return element.outerHtml;
    }
  }

  /// 获取元素的文本节点（包括所有子元素的文本节点）
  /// 参考项目：AnalyzeByJSoup.getResultLast - "textNodes" 分支
  /// element.textNodes() 获取所有文本节点，每个节点单独处理
  /// 注意：参考项目中 textNodes 会递归获取所有文本节点，每个文本节点单独一行
  static String? getTextNodes(html_dom.Element? element) {
    if (element == null) return null;

    try {
      // 获取所有文本节点（递归）
      final textNodes = <String>[];

      // 递归遍历所有节点，提取文本节点
      void extractTextNodes(html_dom.Node node) {
        if (node is html_dom.Text) {
          final text = node.text.trim();
          if (text.isNotEmpty) {
            textNodes.add(text);
          }
        } else if (node is html_dom.Element) {
          // 递归处理所有子节点
          for (final child in node.nodes) {
            extractTextNodes(child);
          }
        }
      }

      // 从元素的直接子节点开始提取（不包括元素本身的文本）
      // 参考项目：element.textNodes() 获取所有文本节点
      for (final child in element.nodes) {
        extractTextNodes(child);
      }

      if (textNodes.isEmpty) return null;
      // 每个文本节点单独一行
      return textNodes.join('\n');
    } catch (e) {
      AppLog.instance.putDebug('HtmlParser.getTextNodes: 获取文本节点失败', error: e);
      return null;
    }
  }

  /// 获取元素自身的文本（不包括子元素的文本）
  /// 参考项目：AnalyzeByJSoup.getResultLast - "ownText" 分支
  /// element.ownText() 只获取直接文本，不包括子元素的文本
  static String? getOwnText(html_dom.Element? element) {
    if (element == null) return null;

    try {
      // 获取元素自身的文本节点（不包括子元素的文本）
      final ownTextNodes = <String>[];

      // 只处理直接子节点中的文本节点
      for (final node in element.nodes) {
        if (node is html_dom.Text) {
          final text = node.text.trim();
          if (text.isNotEmpty) {
            ownTextNodes.add(text);
          }
        }
      }

      if (ownTextNodes.isEmpty) return null;
      return ownTextNodes.join(' ');
    } catch (e) {
      return null;
    }
  }

  /// 获取元素的完整 HTML（不删除script和style）
  /// 参考项目：AnalyzeByJSoup.getResultLast - "all" 分支
  /// elements.outerHtml() 直接返回，不删除script和style
  static String? getAllHtml(html_dom.Element? element) {
    if (element == null) return null;
    return element.outerHtml;
  }

  /// 清理 HTML 标签，只保留文本
  /// 参考项目：JSoup 的 element.text() 会自动将 <br /> 转换为换行符
  /// Dart 的 html 包的 text 属性可能不会自动处理 <br />，需要手动处理
  static String cleanHtml(String html) {
    final document = parse(html);
    final body = document.body;
    if (body == null) return '';
    
    // 使用递归方法提取文本，遇到 <br /> 标签时插入换行符
    // 这样可以确保 <br /> 被正确转换为换行符
    final buffer = StringBuffer();
    _extractTextWithBr(body, buffer);
    final text = buffer.toString();
    
    // 清理多余的换行符（连续多个换行符合并为一个）
    // 但保留单个换行符，因为 <br /> 应该产生换行
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }
}
