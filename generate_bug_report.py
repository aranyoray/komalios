#!/usr/bin/env python3
"""Generate PDF bug report for YouTube redirect issue."""

from fpdf import FPDF

class BugReport(FPDF):
    def header(self):
        self.set_font("Helvetica", "B", 11)
        self.set_text_color(100, 100, 100)
        self.cell(0, 8, "Komal iOS - Bug Report", align="R", new_x="LMARGIN", new_y="NEXT")
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(4)

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(150, 150, 150)
        self.cell(0, 10, f"Page {self.page_no()}/{{nb}}", align="C")

    def section_title(self, title):
        self.set_font("Helvetica", "B", 14)
        self.set_text_color(44, 62, 80)
        self.cell(0, 10, title, new_x="LMARGIN", new_y="NEXT")
        self.ln(2)

    def subsection_title(self, title):
        self.set_font("Helvetica", "B", 11)
        self.set_text_color(52, 73, 94)
        self.cell(0, 8, title, new_x="LMARGIN", new_y="NEXT")
        self.ln(1)

    def body_text(self, text):
        self.set_font("Helvetica", "", 10)
        self.set_text_color(60, 60, 60)
        self.multi_cell(0, 5.5, text)
        self.ln(2)

    def code_block(self, text):
        self.set_font("Courier", "", 8.5)
        self.set_fill_color(245, 245, 245)
        self.set_text_color(40, 40, 40)
        x = self.get_x()
        self.set_x(x + 4)
        self.multi_cell(0, 4.5, text, fill=True)
        self.set_x(x)
        self.ln(3)

    def bullet(self, text):
        self.set_font("Helvetica", "", 10)
        self.set_text_color(60, 60, 60)
        x = self.get_x()
        self.set_x(x + 6)
        self.cell(4, 5.5, "-")
        self.multi_cell(0, 5.5, text)
        self.set_x(x)

    def severity_badge(self, severity):
        colors = {
            "HIGH": (231, 76, 60),
            "MEDIUM": (243, 156, 18),
            "LOW": (46, 204, 113),
        }
        r, g, b = colors.get(severity, (149, 165, 166))
        self.set_fill_color(r, g, b)
        self.set_text_color(255, 255, 255)
        self.set_font("Helvetica", "B", 9)
        w = self.get_string_width(severity) + 10
        self.cell(w, 7, severity, fill=True, align="C")
        self.ln(4)


pdf = BugReport()
pdf.alias_nb_pages()
pdf.set_auto_page_break(auto=True, margin=20)
pdf.add_page()

# Title
pdf.set_font("Helvetica", "B", 22)
pdf.set_text_color(44, 62, 80)
pdf.cell(0, 14, "Bug Report: YouTube Redirect", new_x="LMARGIN", new_y="NEXT")
pdf.cell(0, 10, "from Search Queries", new_x="LMARGIN", new_y="NEXT")
pdf.ln(4)

# Metadata
pdf.set_font("Helvetica", "", 10)
pdf.set_text_color(120, 120, 120)
pdf.cell(0, 6, "Date: February 17, 2026", new_x="LMARGIN", new_y="NEXT")
pdf.cell(0, 6, "Component: KomalSafetyScannerViewModel / Browser Navigation", new_x="LMARGIN", new_y="NEXT")
pdf.cell(0, 6, "Severity: ", new_x="END", new_y="LAST")
pdf.severity_badge("HIGH")
pdf.ln(6)

# ---- Bug Description ----
pdf.section_title("1. Bug Description")
pdf.body_text(
    "When a user types certain search words (e.g., 'funny videos', 'music', 'gaming') into the "
    "Komal browser's omnibox, the browser navigates directly to YouTube instead of displaying "
    "Google search results. This happens without the user clicking any YouTube link."
)

# ---- Root Cause ----
pdf.section_title("2. Root Cause Analysis")
pdf.body_text(
    "The issue originates from how the app handles server scan responses. When a user enters a "
    "search term, the app correctly converts it to a Google Safe Search URL:"
)
pdf.code_block("https://www.google.com/search?q=funny+videos&safe=active")
pdf.body_text(
    "This URL is sent to the Komal server for content analysis. The server fetches the page, "
    "follows any redirects, and returns a UnifiedDecisionResponse or ScanResponse. Critically, "
    "the response includes a 'url' field that may differ from the original URL sent."
)
pdf.body_text(
    "For search terms related to video content, Google's top results point to YouTube. The "
    "server may resolve the destination and return the YouTube URL in the response:"
)
pdf.code_block("Server response: decision.url = 'https://www.youtube.com/results?search_query=funny+videos'")
pdf.body_text(
    "The app then navigates to decision.url instead of the original Google search URL, "
    "causing an unintended redirect to YouTube."
)

# ---- Affected Code ----
pdf.section_title("3. Affected Code Paths")

pdf.subsection_title("Path A: Unified Decision (Primary)")
pdf.body_text("File: KomalSafetyScannerViewModel.swift")
pdf.body_text("Function: handleUnifiedAction(_:decision:)")
pdf.code_block(
    "// BEFORE (Bug): navigates to server-returned URL\n"
    "case .allow:\n"
    "    if let url = URL(string: decision.url) {  // <-- server URL\n"
    "        lastSafeURL = url\n"
    "        currentURL = url  // navigates to YouTube!\n"
    "\n"
    "case .gate:\n"
    "    if let url = URL(string: decision.url) {  // <-- server URL\n"
    "        pendingURL = url  // stores YouTube URL for later"
)

pdf.subsection_title("Path B: Legacy Scan (Fallback)")
pdf.body_text("File: KomalSafetyScannerViewModel.swift")
pdf.body_text("Function: handleAction(_:result:)")
pdf.code_block(
    "// BEFORE (Bug): same pattern with legacy response\n"
    "case .allow:\n"
    "    if let url = URL(string: result.url) {  // <-- server URL\n"
    "        currentURL = url  // navigates to YouTube!\n"
    "\n"
    "case .gate:\n"
    "    if let url = URL(string: result.url) {\n"
    "        pendingURL = url  // stores YouTube URL"
)

pdf.subsection_title("Path C: Fallback when no age action found")
pdf.body_text("File: KomalSafetyScannerViewModel.swift")
pdf.body_text("Function: processScanResult(normalizedURL:)")
pdf.code_block(
    "// BEFORE (Bug): fallback uses server URL\n"
    "if let url = URL(string: result.url) {\n"
    "    currentURL = url  // navigates to YouTube!"
)

# ---- Fix Applied ----
pdf.add_page()
pdf.section_title("4. Fix Applied")
pdf.body_text(
    "All three code paths were updated to use the original normalizedURL (the Google search URL "
    "that the app constructed) for navigation, instead of the server-returned URL. The server "
    "URL is still used for logging and analytics."
)

pdf.subsection_title("Fix A: handleUnifiedAction")
pdf.code_block(
    "// AFTER (Fixed): uses original URL for navigation\n"
    "private func handleUnifiedAction(\n"
    "    _ action: Action,\n"
    "    decision: UnifiedDecisionResponse,\n"
    "    originalURL: String         // <-- NEW parameter\n"
    ") {\n"
    "    case .allow:\n"
    "        if let url = URL(string: originalURL) {  // <-- original URL\n"
    "            currentURL = url  // stays on Google search\n"
    "    case .gate:\n"
    "        if let url = URL(string: originalURL) {\n"
    "            pendingURL = url  // stores original URL\n"
    "}"
)

pdf.subsection_title("Fix B: handleAction (legacy)")
pdf.code_block(
    "// AFTER (Fixed): same pattern for legacy path\n"
    "private func handleAction(\n"
    "    _ action: Action,\n"
    "    result: ScanResponse,\n"
    "    originalURL: String         // <-- NEW parameter\n"
    ") {\n"
    "    case .allow:\n"
    "        if let url = URL(string: originalURL) {\n"
    "            currentURL = url  // stays on Google search\n"
    "    case .gate:\n"
    "        if let url = URL(string: originalURL) {\n"
    "            pendingURL = url\n"
    "}"
)

pdf.subsection_title("Fix C: processScanResult fallback")
pdf.code_block(
    "// AFTER (Fixed): fallback uses normalizedURL\n"
    "if let url = URL(string: normalizedURL) {  // <-- original URL\n"
    "    currentURL = url"
)

# ---- Call Sites Updated ----
pdf.section_title("5. Call Sites Updated")
pdf.bullet("processUnifiedWithAction() now passes normalizedURL to handleUnifiedAction()")
pdf.bullet("processScanResult() now passes normalizedURL to handleAction()")
pdf.ln(4)

# ---- Additional Fixes ----
pdf.section_title("6. Additional Fixes (Previous Session)")
pdf.body_text(
    "Default/fallback redirect URLs were also changed from external platforms to Google:"
)
pdf.bullet("BrowserView.swift: Intervention dismissal redirect changed from khanacademy.org to google.com")
pdf.bullet("BrowserViewModel.swift: Default browser URL changed from khanacademy.org to google.com")
pdf.ln(4)

# ---- Reproduction Steps ----
pdf.section_title("7. Reproduction Steps (Before Fix)")
pdf.bullet("1. Open Komal browser")
pdf.bullet("2. Type 'funny videos' or 'music' in the omnibox")
pdf.bullet("3. Press Enter/Submit")
pdf.bullet("4. Observe: browser navigates directly to YouTube instead of Google search results")
pdf.ln(4)

# ---- Expected Behavior ----
pdf.section_title("8. Expected Behavior (After Fix)")
pdf.bullet("Search terms always show Google search results first")
pdf.bullet("YouTube is accessible if user clicks a YouTube link in search results")
pdf.bullet("YouTube is not blocked (no intervention popup)")
pdf.bullet("App never automatically redirects to YouTube or any external platform")
pdf.ln(4)

# ---- Build Verification ----
pdf.section_title("9. Build Verification")
pdf.body_text(
    "All changes compile successfully:"
)
pdf.code_block(
    "$ xcodebuild build -scheme Komalios \\\n"
    "    -destination 'generic/platform=iOS' \\\n"
    "    CODE_SIGNING_ALLOWED=NO\n"
    "\n"
    "** BUILD SUCCEEDED **"
)

# ---- Files Modified ----
pdf.section_title("10. Files Modified")
pdf.set_font("Courier", "", 9)
pdf.set_text_color(60, 60, 60)
files = [
    "Sources/Komalios/PostAuth/BrowserView/ViewModel/KomalSafetyScannerViewModel.swift",
    "Sources/Komalios/PostAuth/BrowserView/View/BrowserView.swift",
    "Sources/Komalios/PostAuth/BrowserView/ViewModel/BrowserViewModel.swift",
]
for f in files:
    pdf.cell(0, 5, f"  {f}", new_x="LMARGIN", new_y="NEXT")

output_path = "/Users/aranyoray/Documents/komalios/YouTube_Redirect_Bug_Report.pdf"
pdf.output(output_path)
print(f"PDF generated: {output_path}")
