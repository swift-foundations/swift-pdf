// Snapshot Tests.swift

import PDF
import Test_Snapshot_Primitives
import Testing
import Tests_Inline_Snapshot

extension PDF {
    #Tests(snapshots: .init(recording: .all, subdirectory: "PDF.Test.Snapshot"))
}

// MARK: - Snapshot Tests

extension PDF.Test.Snapshot {
    @Test
    func `all elements`() {
        let doc = PDF.Document(
            info: .init(title: "All Elements Demo", author: "Test Suite"),
            generateOutline: true
        ) {
            ComplexView()
        }

        snapshot(as: .pdfStructure, named: "all-elements") { doc }
        snapshot(as: .pdf, named: "all-elements") { doc }
    }

    @Test
    func `table elements`() {
        let doc = PDF.Document(
            info: .init(title: "Table Elements Demo", author: "Test Suite"),
            generateOutline: true
        ) {
            TableDemoView()
            TableDemoView2()
        }

        snapshot(as: .pdfStructure, named: "table-elements") { doc }
        snapshot(as: .pdf, named: "table-elements") { doc }
    }

    @Test
    func `NDA layout`() {
        let doc = PDF.Document(
            info: .init(title: "NDA Layout Demo", author: "Test Suite"),
            generateOutline: true
        ) {
            NDADemoView()
        }

        snapshot(as: .pdfStructure, named: "nda-layout") { doc }
        snapshot(as: .pdf, named: "nda-layout") { doc }
    }

    @Test
    func `nested outline`() {
        let doc = PDF.Document(
            info: .init(title: "Technical Specification", author: "Test Suite"),
            generateOutline: true
        ) {
            TechnicalSpecificationView()
        }

        snapshot(as: .pdfStructure, named: "nested-outline") { doc }
        snapshot(as: .pdf, named: "nested-outline") { doc }
    }
}

// MARK: - Top-Level Test Views

struct TechnicalSpecificationView: HTML.View {
    var body: some HTML.View {
        TechSpecFrontMatter()
        TechSpecSections4Through6()
        TechSpecSections7Through9()
        TechSpecAnnexes()
    }
}

struct ComplexView: HTML.View {
    var body: some HTML.View {
        TextStylingDemo()
        LinksDemo()
        BlockElementsDemo()
        ListsDemo()
        HeadingsDemo()
        DescriptionListDemo()
        SemanticDemo()
        FigureDemo()
        NestedListDemo()
        InlineStyleDemo()
        Paragraph { Emphasis { "End of demo." } }
    }
}

struct TableDemoView: HTML.View {
    var body: some HTML.View {
        TableDemoHeader()
        TableSection6_1()
        TableSection6_2()
        TableSection6_3()
    }
}

struct TableDemoView2: HTML.View {
    var body: some HTML.View {
        TableSection6_4()
        TableSection6_5()
        TableSection6_6()
        TableSection6_7()
    }
}

struct NDADemoView: HTML.View {
    var body: some HTML.View {
        NDADemoPreamble()
        NDADemoArticles()
        NDADemoClosing()
    }
}

// MARK: - Technical Specification Sub-Views

private struct TechSpecFrontMatter: HTML.View {
    var body: some HTML.View {
        H1 { "Technical Specification XYZ-2024" }
            .css.textAlign(.center)
        Paragraph { "A comprehensive guide to the XYZ standard." }

        H1 { "1 Scope" }
        Paragraph { "This document specifies the requirements for XYZ systems." }

        H1 { "2 Normative references" }
        Paragraph { "The following documents are referred to in the text." }

        H1 { "3 Terms and definitions" }
        Paragraph { "For the purposes of this document, the following terms apply." }
    }
}

private struct TechSpecSections4Through6: HTML.View {
    var body: some HTML.View {
        H1 { "4 Notation" }
        Paragraph { "This section describes the notation used throughout the document." }

        H2 { "4.1 General" }
        Paragraph { "General notation conventions are described here." }

        H2 { "4.2 Established notations" }
        Paragraph { "Industry-standard notations that are adopted." }

        H2 { "4.3 Special symbols" }
        Paragraph { "Special symbols used in this specification." }

        H3 { "4.3.1 Mathematical symbols" }
        Paragraph { "Symbols used for mathematical expressions." }

        H3 { "4.3.2 Logical symbols" }
        Paragraph { "Symbols used for logical operations." }

        H1 { "5 Version designations" }
        Paragraph { "How versions are designated in this standard." }

        H1 { "6 Conformance" }
        Paragraph { "Requirements for conformance to this specification." }

        H2 { "6.1 Conformance levels" }
        Paragraph { "Different levels of conformance are defined." }

        H3 { "6.1.1 Basic conformance" }
        Paragraph { "Minimum requirements for basic conformance." }

        H3 { "6.1.2 Full conformance" }
        Paragraph { "Requirements for full conformance." }

        H4 { "6.1.2.1 Mandatory features" }
        Paragraph { "Features that must be implemented." }

        H4 { "6.1.2.2 Optional features" }
        Paragraph { "Features that may optionally be implemented." }

        H2 { "6.2 Conformance testing" }
        Paragraph { "How conformance is verified." }
    }
}

private struct TechSpecSections7Through9: HTML.View {
    var body: some HTML.View {
        H1 { "7 Syntax" }
        Paragraph { "The syntax of the XYZ language." }

        H2 { "7.1 Lexical elements" }
        Paragraph { "Basic lexical elements of the language." }

        H2 { "7.2 Expressions" }
        Paragraph { "How expressions are formed." }

        H2 { "7.3 Statements" }
        Paragraph { "Statement syntax and semantics." }

        H1 { "8 Graphics" }
        Paragraph { "Graphics capabilities of the system." }

        H2 { "8.1 Coordinate systems" }
        Paragraph { "How coordinates are specified." }

        H2 { "8.2 Transformations" }
        Paragraph { "Geometric transformations supported." }

        H1 { "9 Text" }
        Paragraph { "Text handling capabilities." }

        H2 { "9.1 General" }
        Paragraph { "Overview of text handling." }

        H2 { "9.2 Organisation and use of fonts" }
        Paragraph { "How fonts are organized and used." }

        H3 { "9.2.1 Font types" }
        Paragraph { "Different types of fonts supported." }

        H3 { "9.2.2 Font embedding" }
        Paragraph { "How fonts are embedded in documents." }

        H2 { "9.3 Text state parameters and operators" }
        Paragraph { "Parameters that control text rendering." }

        H2 { "9.4 Text objects" }
        Paragraph { "How text objects are defined." }

        H2 { "9.5 Introduction to font data structures" }
        Paragraph { "Overview of font data structures." }

        H2 { "9.6 Simple fonts" }
        Paragraph { "Simple font types and their properties." }

        H3 { "9.6.1 Type 1 fonts" }
        Paragraph { "Adobe Type 1 font format." }

        H3 { "9.6.2 TrueType fonts" }
        Paragraph { "TrueType font format." }

        H2 { "9.7 Composite fonts" }
        Paragraph { "Composite font architecture." }

        H2 { "9.8 Font descriptors" }
        Paragraph { "Metadata about fonts." }
    }
}

private struct TechSpecAnnexes: HTML.View {
    var body: some HTML.View {
        H1 { "Annex A (normative) Implementation notes" }
        Paragraph { "Notes for implementers of this specification." }

        H1 { "Annex B (informative) Examples" }
        Paragraph { "Example implementations and use cases." }

        H2 { "B.1 Basic example" }
        Paragraph { "A simple example demonstrating core features." }

        H2 { "B.2 Advanced example" }
        Paragraph { "A complex example showing advanced features." }
    }
}

// MARK: - All Elements Sub-Views

private struct TextStylingDemo: HTML.View {
    var body: some HTML.View {
        H1 { "All HTML Elements Demo" }
        H2 { "1. Text Styling" }
        Paragraph {
            "Normal, "
            StrongImportance { "bold" }
            ", "
            Emphasis { "italic" }
            ", "
            Code { "code" }
            "."
        }
        Paragraph {
            Mark { "highlighted" }
            ", "
            Strikethrough { "strikethrough" }
            ", "
            UnarticulatedAnnotation { "underline" }
            "."
        }
        Paragraph {
            "H"
            Subscript { "2" }
            "O, E=mc"
            Superscript { "2" }
            "."
        }
        Paragraph {
            "Read "
            Cite { "1984" }
            " by George Orwell."
        }
        Paragraph {
            "Press "
            KeyboardInput { "Ctrl+C" }
            " to copy."
        }
        Paragraph {
            "Output: "
            Samp { "Hello, World!" }
        }
        Paragraph {
            "Let "
            Variable { "x" }
            " = 5."
        }
        Paragraph {
            "The "
            Definition { "DOM" }
            " is the Document Object Model."
        }
        Paragraph {
            "The "
            Abbreviation { "HTML" }
            " specification."
        }
        Paragraph {
            "She said, "
            InlineQuotation { "Hello!" }
        }
        Paragraph {
            "Line 1"
            BR()
            "Line 2 (after BR)"
        }
        Paragraph {
            "Meeting at "
            Time { "2024-01-15" }
            "."
        }
    }
}

private struct LinksDemo: HTML.View {
    var body: some HTML.View {
        H2 { "2. Links" }
        Paragraph {
            "Visit "
            Anchor(href: "https://example.com") { "Example Website" }
            " for more info."
        }
        Paragraph {
            "Contact: "
            Anchor(href: "mailto:test@example.com") { "test@example.com" }
        }
    }
}

private struct BlockElementsDemo: HTML.View {
    var body: some HTML.View {
        H2 { "3. Block Elements" }
        BlockQuote {
            Paragraph { "This is a block quotation." }
        }
        PreformattedText {
            "func hello() {\n    print(\"Hello\")\n}"
        }
    }
}

private struct ListsDemo: HTML.View {
    var body: some HTML.View {
        ListsDemoBasic()
        ListsDemoAdvanced()
    }
}

private struct ListsDemoBasic: HTML.View {
    var body: some HTML.View {
        H2 { "4. Lists" }
            .css.pageBreakAfter(.avoid)

        H3 { "4.1 Simple Unordered List" }
            .css.pageBreakAfter(.avoid)

        UnorderedList {
            ListItem { "First bullet point" }
            ListItem { "Second bullet point" }
            ListItem { "Third bullet point" }
        }

        H3 { "4.2 Simple Ordered List" }
        OrderedList {
            ListItem { "First numbered item" }
            ListItem { "Second numbered item" }
            ListItem { "Third numbered item" }
        }

        H3 { "4.3 List Items with Wrapping Text" }
        OrderedList {
            ListItem {
                "This is a longer list item that should wrap to multiple lines to test how the list marker aligns with multi-line content in an ordered list."
            }
            ListItem {
                "Another lengthy item with sufficient text to cause line wrapping and verify proper indentation is maintained throughout."
            }
            ListItem { "Short item." }
        }

        H3 { "4.4 List Items with Inline Formatting" }
        UnorderedList {
            ListItem {
                StrongImportance { "Bold text" }
                " followed by normal text"
            }
            ListItem {
                "Normal text with "
                Emphasis { "italic" }
                " in the middle"
            }
            ListItem {
                Code { "inline code" }
                " mixed with regular text"
            }
            ListItem {
                "Link: "
                Anchor(href: "https://example.com") { "Example Website" }
            }
        }

        H3 { "4.5 Nested Lists" }
        UnorderedList {
            ListItem { "Level 1 - Item A" }
            ListItem {
                "Level 1 - Item B with nested list:"
                UnorderedList {
                    ListItem { "Level 2 - Nested item 1" }
                    ListItem { "Level 2 - Nested item 2" }
                    ListItem {
                        "Level 2 - Item with deeper nesting:"
                        UnorderedList {
                            ListItem { "Level 3 - Deep nested item" }
                        }
                    }
                }
            }
            ListItem { "Level 1 - Item C" }
        }
    }
}

private struct ListsDemoAdvanced: HTML.View {
    var body: some HTML.View {
        H3 { "4.6 Mixed Nested Lists" }
        OrderedList {
            ListItem { "First main item" }
            ListItem {
                "Second main item with sub-points:"
                UnorderedList {
                    ListItem { "Sub-point A" }
                    ListItem { "Sub-point B" }
                    ListItem { "Sub-point C" }
                }
            }
            ListItem {
                "Third main item with numbered sub-items:"
                OrderedList {
                    ListItem { "Sub-item 1" }
                    ListItem { "Sub-item 2" }
                }
            }
        }

        H3 { "4.7 List with Many Items" }
        OrderedList {
            ListItem { "Item one" }
            ListItem { "Item two" }
            ListItem { "Item three" }
            ListItem { "Item four" }
            ListItem { "Item five" }
            ListItem { "Item six" }
            ListItem { "Item seven" }
            ListItem { "Item eight" }
            ListItem { "Item nine" }
            ListItem { "Item ten" }
            ListItem { "Item eleven" }
            ListItem { "Item twelve" }
        }

        H3 { "4.8 List Spacing" }
        Paragraph {
            "This paragraph comes before a list. There should be appropriate spacing between this text and the list below."
        }
        UnorderedList {
            ListItem { "First item after paragraph" }
            ListItem { "Second item" }
        }
        Paragraph {
            "This paragraph comes after the list. Spacing should also be appropriate here."
        }

        H3 { "4.9 Single Item Lists" }
        UnorderedList {
            ListItem { "Only item in unordered list" }
        }
        OrderedList {
            ListItem { "Only item in ordered list" }
        }
    }
}

private struct HeadingsDemo: HTML.View {
    var body: some HTML.View {
        H2 { "5. Headings" }
        H1 { "H1" }
        H2 { "H2" }
        H3 { "H3" }
        H4 { "H4" }
        H5 { "H5" }
        H6 { "H6" }
    }
}

// MARK: - Table Sub-Views

private struct TableDemoHeader: HTML.View {
    var body: some HTML.View {
        H2 { "6. Tables" }
            .css.pageBreakAfter(.avoid)
    }
}

private struct TableSection6_1: HTML.View {
    var body: some HTML.View {
        H3 { "6.1 Simple Data Table" }
            .css.pageBreakAfter(.avoid)

        Table {
            Caption { "Employee Directory" }
            TableHead {
                TableRow {
                    TableHeader { "Name" }
                    TableHeader { "Age" }
                    TableHeader { "City" }
                }
            }
            TableBody {
                TableRow {
                    TableDataCell { "Alice" }
                    TableDataCell { "30" }
                    TableDataCell { "New York" }
                }
                TableRow {
                    TableDataCell { "Bob" }
                    TableDataCell { "25" }
                    TableDataCell { "Los Angeles" }
                }
                TableRow {
                    TableDataCell { "Charlie" }
                    TableDataCell { "35" }
                    TableDataCell { "Chicago" }
                }
                TableRow {
                    TableDataCell { "Diana" }
                    TableDataCell { "28" }
                    TableDataCell { "Houston" }
                }
            }
        }
    }
}

private struct TableSection6_2: HTML.View {
    var body: some HTML.View {
        H3 { "6.2 Product Inventory" }
            .css.pageBreakAfter(.avoid)

        Table {
            TableHead {
                TableRow {
                    TableHeader { "SKU" }
                    TableHeader { "Product" }
                    TableHeader { "Price" }
                    TableHeader { "Stock" }
                }
            }
            TableBody {
                TableRow {
                    TableDataCell { "A001" }
                    TableDataCell { "Wireless Mouse" }
                    TableDataCell { "$29.99" }
                    TableDataCell { "150" }
                }
                TableRow {
                    TableDataCell { "A002" }
                    TableDataCell { "USB-C Hub" }
                    TableDataCell { "$49.99" }
                    TableDataCell { "75" }
                }
                TableRow {
                    TableDataCell { "B001" }
                    TableDataCell { "Ergonomic Chair" }
                    TableDataCell { "$299.00" }
                    TableDataCell { "25" }
                }
            }
        }
    }
}

private struct TableSection6_3: HTML.View {
    var body: some HTML.View {
        H3 { "6.3 Table with Formatted Content" }
            .css.pageBreakAfter(.avoid)

        Table {
            TableHead {
                TableRow {
                    TableHeader { "Feature" }
                    TableHeader { "Status" }
                    TableHeader { "Notes" }
                }
            }
            TableBody {
                TableRow {
                    TableDataCell {
                        StrongImportance { "Authentication" }
                    }
                    TableDataCell { "Complete" }
                    TableDataCell {
                        "Supports "
                        Code { "OAuth 2.0" }
                        " and "
                        Code { "JWT" }
                    }
                }
                TableRow {
                    TableDataCell {
                        StrongImportance { "API Gateway" }
                    }
                    TableDataCell { "In Progress" }
                    TableDataCell {
                        Emphasis { "Expected Q2 2025" }
                    }
                }
                TableRow {
                    TableDataCell {
                        StrongImportance { "Dashboard" }
                    }
                    TableDataCell { "Planned" }
                    TableDataCell { "See roadmap for details" }
                }
            }
        }
    }
}

private struct TableSection6_4: HTML.View {
    var body: some HTML.View {
        H3 { "6.4 Financial Summary with Footer" }
            .css.pageBreakAfter(.avoid)

        Table {
            TableHead {
                TableRow {
                    TableHeader { "Quarter" }
                    TableHeader { "Revenue" }
                    TableHeader { "Expenses" }
                    TableHeader { "Profit" }
                }
            }
            TableBody {
                TableRow {
                    TableDataCell { "Q1 2024" }
                    TableDataCell { "$125,000" }
                    TableDataCell { "$95,000" }
                    TableDataCell { "$30,000" }
                }
                TableRow {
                    TableDataCell { "Q2 2024" }
                    TableDataCell { "$142,000" }
                    TableDataCell { "$98,000" }
                    TableDataCell { "$44,000" }
                }
                TableRow {
                    TableDataCell { "Q3 2024" }
                    TableDataCell { "$158,000" }
                    TableDataCell { "$102,000" }
                    TableDataCell { "$56,000" }
                }
            }
            TableFoot {
                TableRow {
                    TableHeader { "Total" }
                    TableDataCell { "$425,000" }
                    TableDataCell { "$288,000" }
                    TableDataCell {
                        StrongImportance { "$137,000" }
                    }
                }
            }
        }
    }
}

private struct TableSection6_5: HTML.View {
    var body: some HTML.View {
        H3 { "6.5 Key-Value Table" }
            .css.pageBreakAfter(.avoid)

        Table {
            TableBody {
                TableRow {
                    TableHeader { "Version" }
                    TableDataCell { "2.4.1" }
                }
                TableRow {
                    TableHeader { "Release Date" }
                    TableDataCell { "December 10, 2024" }
                }
                TableRow {
                    TableHeader { "License" }
                    TableDataCell { "MIT" }
                }
                TableRow {
                    TableHeader { "Author" }
                    TableDataCell { "Coen ten Thije Boonkkamp" }
                }
                TableRow {
                    TableHeader { "Repository" }
                    TableDataCell { "github.com/coenttb/swift-pdf-html-rendering" }
                }
            }
        }
    }
}

private struct TableSection6_6: HTML.View {
    var body: some HTML.View {
        H3 { "6.6 Colspan/Rowspan Table" }
            .css.pageBreakAfter(.avoid)

        Table {
            TableHead {
                TableRow {
                    TableHeader { "Category" }
                    TableHeader(colspan: 2) { "Details" }
                    TableHeader { "Status" }
                }
            }
            TableBody {
                TableRow {
                    TableHeader(rowspan: 2) { "Rendering" }
                    TableDataCell { "Tables" }
                    TableDataCell { "Full support" }
                    TableDataCell { "✓" }
                }
                TableRow {
                    TableDataCell { "Lists" }
                    TableDataCell { "Full support" }
                    TableDataCell { "✓" }
                }
                TableRow {
                    TableDataCell { "Typography" }
                    TableDataCell { "Headings" }
                    TableDataCell { "H1-H6" }
                    TableDataCell { "✓" }
                }
                TableRow {
                    TableDataCell(colspan: 3) { "Combined colspan example spanning three columns" }
                    TableDataCell { "OK" }
                }
            }
            TableFoot {
                TableRow {
                    TableDataCell(colspan: 4) { "All features implemented and tested" }
                }
            }
        }
    }
}

private struct TableSection6_7: HTML.View {
    var body: some HTML.View {
        H3 { "6.7 Text Alignment (CSS)" }
            .css.pageBreakAfter(.avoid)

        Table {
            TableHead {
                TableRow {
                    TableHeader { "Product" }
                    TableHeader { "Quantity" }
                        .css.textAlign(.right)
                    TableHeader { "Price" }
                        .css.textAlign(.right)
                    TableHeader { "Total" }
                        .css.textAlign(.right)
                }
            }
            TableBody {
                TableRow {
                    TableDataCell { "Widget A" }
                    TableDataCell { "10" }
                        .css.textAlign(.right)
                    TableDataCell { "$5.00" }
                        .css.textAlign(.right)
                    TableDataCell { "$50.00" }
                        .css.textAlign(.right)
                }
                TableRow {
                    TableDataCell { "Widget B" }
                    TableDataCell { "25" }
                        .css.textAlign(.right)
                    TableDataCell { "$3.50" }
                        .css.textAlign(.right)
                    TableDataCell { "$87.50" }
                        .css.textAlign(.right)
                }
                TableRow {
                    TableDataCell { "Service Fee" }
                    TableDataCell { "—" }
                        .css.textAlign(.center)
                    TableDataCell { "—" }
                        .css.textAlign(.center)
                    TableDataCell { "$15.00" }
                        .css.textAlign(.right)
                }
            }
            TableFoot {
                TableRow {
                    TableHeader(colspan: 3) { "Grand Total" }
                        .css.textAlign(.right)
                    TableDataCell { "$152.50" }
                        .css.textAlign(.right)
                }
            }
        }
    }
}

// MARK: - Other Element Sub-Views

private struct DescriptionListDemo: HTML.View {
    var body: some HTML.View {
        DescriptionList {
            DescriptionTerm { "HTML" }
            DescriptionDetails { "HyperText Markup Language" }
            DescriptionTerm { "CSS" }
            DescriptionDetails { "Cascading Style Sheets" }
            DescriptionTerm { "PDF" }
            DescriptionDetails { "Portable Document Format" }
        }
    }
}

private struct SemanticDemo: HTML.View {
    var body: some HTML.View {
        Article {
            Header {
                H3 { "Article Title" }
            }
            Section {
                Paragraph { "Main content of the article." }
            }
            Footer {
                Paragraph { Small { "Author: Test Suite" } }
            }
        }
    }
}

private struct FigureDemo: HTML.View {
    var body: some HTML.View {
        Figure {
            Paragraph { "[Image placeholder]" }
            FigureCaption { "Figure 1: Sample figure." }
        }
    }
}

private struct NestedListDemo: HTML.View {
    var body: some HTML.View {
        UnorderedList {
            ListItem { "Item 1" }
            ListItem {
                "Item 2 with nested:"
                UnorderedList {
                    ListItem { "Nested 2.1" }
                    ListItem { "Nested 2.2" }
                }
            }
            ListItem { "Item 3" }
        }
    }
}

// MARK: - NDA Sub-Views

private struct NDADemoPreamble: HTML.View {
    var body: some HTML.View {
        ContentDivision {
            H1 { "NON-DISCLOSURE AGREEMENT" }
                .css.textAlign(.center)
        }
        .css.pageBreakBefore(.always)

        Paragraph {
            StrongImportance { "THIS NON-DISCLOSURE AGREEMENT" }
            " (the \"Agreement\") is entered into as of "
            ContentSpan { "[DATE]" }
                .css.textDecoration(.underline)
            " by and between:"
        }

        Paragraph {
            StrongImportance { "DISCLOSING PARTY:" }
            BR()
            "[Company Name], a [State] corporation, with its principal place of business at [Address] (\"Discloser\")"
        }

        Paragraph {
            StrongImportance { "RECEIVING PARTY:" }
            BR()
            "[Recipient Name], an individual/entity located at [Address] (\"Recipient\")"
        }

        Paragraph {
            "(Discloser and Recipient are collectively referred to as the \"Parties\")"
        }

        H2 { "RECITALS" }
            .css.pageBreakAfter(.avoid)

        Paragraph {
            StrongImportance { "WHEREAS" }
            ", the Discloser possesses certain confidential and proprietary information relating to [describe business/technology/project] (the \"Purpose\"); and"
        }

        Paragraph {
            StrongImportance { "WHEREAS" }
            ", the Recipient desires to receive certain Confidential Information for the Purpose; and"
        }

        Paragraph {
            StrongImportance { "NOW, THEREFORE" }
            ", in consideration of the mutual covenants and agreements set forth herein, and for other good and valuable consideration, the receipt and sufficiency of which are hereby acknowledged, the Parties agree as follows:"
        }
    }
}

private struct NDADemoArticles: HTML.View {
    var body: some HTML.View {
        H2 { "ARTICLE 1: DEFINITIONS" }
            .css.pageBreakAfter(.avoid)

        Paragraph {
            StrongImportance { "1.1 \"Confidential Information\"" }
            " means any and all information or data, whether oral, written, electronic, or visual, that is disclosed by the Discloser to the Recipient, including but not limited to:"
        }

        OrderedList {
            ListItem {
                "Trade secrets, inventions, ideas, processes, formulas, source code, and software;"
            }
            ListItem { "Business plans, financial information, and customer lists;" }
            ListItem { "Technical data, know-how, and research findings;" }
            ListItem {
                "Any other information designated as \"Confidential\" at the time of disclosure."
            }
        }

        H2 { "ARTICLE 2: OBLIGATIONS OF RECIPIENT" }
            .css.pageBreakAfter(.avoid)

        Paragraph {
            StrongImportance { "2.1 Non-Disclosure." }
            " The Recipient agrees to hold and maintain the Confidential Information in strict confidence and shall not, without the prior written approval of the Discloser:"
        }

        OrderedList {
            ListItem { "Disclose any Confidential Information to any third parties;" }
            ListItem { "Use the Confidential Information for any purpose other than the Purpose;" }
            ListItem {
                "Copy or reproduce the Confidential Information except as necessary for the Purpose."
            }
        }

        Paragraph {
            StrongImportance { "2.2 Standard of Care." }
            " The Recipient shall protect the Confidential Information using the same degree of care it uses to protect its own confidential information, but in no event less than reasonable care."
        }

        H2 { "ARTICLE 3: TERM AND TERMINATION" }
            .css.pageBreakAfter(.avoid)

        Paragraph {
            StrongImportance { "3.1 Term." }
            " This Agreement shall remain in effect for a period of "
            ContentSpan { "[NUMBER]" }
                .css.textDecoration(.underline)
            " years from the Effective Date, unless earlier terminated in accordance with this Agreement."
        }

        Paragraph {
            StrongImportance { "3.2 Survival." }
            " The confidentiality obligations under this Agreement shall survive termination and continue for a period of "
            ContentSpan { "[NUMBER]" }
                .css.textDecoration(.underline)
            " years following termination."
        }
    }
}

private struct NDADemoClosing: HTML.View {
    var body: some HTML.View {
        H2 { "ARTICLE 4: GENERAL PROVISIONS" }
            .css.pageBreakAfter(.avoid)

        Paragraph {
            StrongImportance { "4.1 Governing Law." }
            " This Agreement shall be governed by and construed in accordance with the laws of the State of "
            ContentSpan { "[STATE]" }
                .css.textDecoration(.underline)
            ", without regard to its conflict of laws principles."
        }

        Paragraph {
            StrongImportance { "4.2 Entire Agreement." }
            " This Agreement constitutes the entire agreement between the Parties with respect to the subject matter hereof and supersedes all prior negotiations, representations, or agreements relating thereto."
        }

        Paragraph {
            StrongImportance { "4.3 Amendments." }
            " This Agreement may not be amended or modified except by a written instrument signed by both Parties."
        }

        H2 { "SIGNATURES" }
            .css.pageBreakAfter(.avoid)

        Paragraph {
            StrongImportance { "IN WITNESS WHEREOF" }
            ", the Parties have executed this Non-Disclosure Agreement as of the date first written above."
        }

        Paragraph {
            StrongImportance { "DISCLOSER:" }
        }
        .css.pageBreakAfter(.avoid)

        Paragraph {
            BR()
            "________________________________"
            BR()
            "Name: [Authorized Representative]"
            BR()
            "Title: [Title]"
            BR()
            "Date: _______________"
        }

        Paragraph {
            StrongImportance { "RECIPIENT:" }
        }
        .css.pageBreakAfter(.avoid)

        Paragraph {
            BR()
            "________________________________"
            BR()
            "Name: [Recipient Name]"
            BR()
            "Title: [Title]"
            BR()
            "Date: _______________"
        }
    }
}

private struct InlineStyleDemo: HTML.View {
    var body: some HTML.View {
        H2 { "10. CSS Styling" }
        Paragraph {
            "Color: "
            ContentSpan { "red" }
                .css.color(.red)
            ", "
            ContentSpan { "blue" }
                .css.color(.blue)
            ", "
            ContentSpan { "green" }
                .css.color(.green)
            "."
        }
        Paragraph {
            "Background: "
            ContentSpan { " highlighted " }
                .css.backgroundColor(.yellow)
            " text."
        }
        Paragraph {
            "Font weight: "
            ContentSpan { "bold" }
                .css.fontWeight(.bold)
            ", "
            ContentSpan { "normal" }
                .css.fontWeight(.normal)
            "."
        }
        Paragraph {
            "Font style: "
            ContentSpan { "italic" }
                .css.fontStyle(.italic)
            ", "
            ContentSpan { "normal" }
                .css.fontStyle(.normal)
            "."
        }
        Paragraph {
            "Font size: "
            ContentSpan { "small" }
                .css.fontSize(.absoluteSize(.small))
            ", "
            ContentSpan { "large" }
                .css.fontSize(.absoluteSize(.large))
            ", "
            ContentSpan { "x-large" }
                .css.fontSize(.absoluteSize(.xLarge))
            "."
        }
        ContentDivision {
            Paragraph { "Content in a div." }
        }
    }
}
