//
//  TestCSS.swift
//  PDFTestSupport
//
//  Reusable CSS styles for PDF testing
//

import Foundation

/// Common CSS styles for visual verification tests
public enum TestCSS {
    /// Modern document styling with gradients, sections, and responsive layout
    public static let modern = """
    body {
        font-family: 'Helvetica Neue', Arial, sans-serif;
        padding: 30px;
        line-height: 1.6;
        color: #333;
    }
    .header {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 30px;
        text-align: center;
        border-radius: 8px;
        margin-bottom: 20px;
    }
    .header h1 {
        margin: 0;
        font-size: 32px;
    }
    .section {
        margin: 20px 0;
        padding: 20px;
        background: #f8f9fa;
        border-left: 4px solid #667eea;
        border-radius: 4px;
    }
    .section h2 {
        margin-top: 0;
        color: #667eea;
    }
    code {
        background: #f4f4f4;
        padding: 2px 6px;
        border-radius: 3px;
        font-family: 'Monaco', monospace;
        color: #e83e8c;
    }
    .warning {
        background: #fff3cd;
        border-left-color: #ffc107;
        color: #856404;
    }
    .success {
        background: #d4edda;
        border-left-color: #28a745;
        color: #155724;
    }
    .footer {
        margin-top: 30px;
        padding: 20px;
        text-align: center;
        color: #6c757d;
        border-top: 2px solid #e9ecef;
    }
    """

    /// Rich verification CSS with tables, grids, and complex layouts
    public static let richVerification = """
    body {
        font-family: 'Helvetica Neue', Arial, sans-serif;
        line-height: 1.6;
        color: #333;
    }
    .header {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 40px;
        text-align: center;
        border-radius: 8px;
        margin-bottom: 30px;
    }
    .header h1 {
        margin: 0;
        font-size: 48px;
        font-weight: bold;
    }
    .header p {
        margin: 10px 0 0 0;
        font-size: 18px;
        opacity: 0.9;
    }
    .section {
        margin: 30px 0;
        padding: 20px;
        background: #f8f9fa;
        border-left: 4px solid #667eea;
        border-radius: 4px;
    }
    .section h2 {
        margin-top: 0;
        color: #667eea;
    }
    .feature-grid {
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        gap: 20px;
        margin: 20px 0;
    }
    .feature {
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .feature h3 {
        margin-top: 0;
        color: #764ba2;
    }
    table {
        width: 100%;
        border-collapse: collapse;
        margin: 20px 0;
        background: white;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    th {
        background: #667eea;
        color: white;
        padding: 12px;
        text-align: left;
    }
    td {
        padding: 12px;
        border-bottom: 1px solid #e9ecef;
    }
    tr:hover {
        background: #f8f9fa;
    }
    code {
        background: #f4f4f4;
        padding: 2px 6px;
        border-radius: 3px;
        font-family: 'Monaco', 'Courier New', monospace;
        color: #e83e8c;
    }
    .footer {
        margin-top: 40px;
        padding: 20px;
        text-align: center;
        color: #6c757d;
        border-top: 2px solid #e9ecef;
    }
    """
}
