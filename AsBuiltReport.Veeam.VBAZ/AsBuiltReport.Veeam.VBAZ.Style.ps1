# Document-level options (page size, default font, margins, orientation).
# Mirrors the AsBuiltReport.Core default style so the Veeam style is self-contained.
$DocumentOrientation = if ($Orientation) { $Orientation } else { 'Portrait' }
DocumentOption -EnableSectionNumbering -PageSize A4 -DefaultFont 'Segoe Ui' -MarginLeftAndRight 71 -MarginTopAndBottom 71 -Orientation $DocumentOrientation

# Veeam default heading and font styles.
Style -Name 'Title' -Size 24 -Color '005f4b' -Align Center
Style -Name 'Title 2' -Size 18 -Color '565656' -Align Center
Style -Name 'Title 3' -Size 12 -Color '565656' -Align Left
Style -Name 'Heading 1' -Size 16 -Color '005f4b'
Style -Name 'NO TOC Heading 1' -Size 16 -Color '005f4b'
Style -Name 'Heading 2' -Size 14 -Color '005f4b'
Style -Name 'NO TOC Heading 2' -Size 14 -Color '005f4b'
Style -Name 'Heading 3' -Size 12 -Color '005f4b'
Style -Name 'NO TOC Heading 3' -Size 12 -Color '005f4b'
Style -Name 'Heading 4' -Size 11 -Color '005f4b'
Style -Name 'NO TOC Heading 4' -Size 11 -Color '005f4b'
Style -Name 'Heading 5' -Size 10 -Color '005f4b'
Style -Name 'NO TOC Heading 5' -Size 10 -Color '005f4b'
Style -Name 'Heading 6' -Size 10 -Color '005f4b'
Style -Name 'NO TOC Heading 6' -Size 10 -Color '005f4b'
Style -Name 'NO TOC Heading 7' -Size 10 -Color '00EBCD' -Italic
Style -Name 'Normal' -Size 10 -Color '565656' -Default

# Header and footer styles.
Style -Name 'Header' -Size 10 -Color '565656' -Align Center
Style -Name 'Footer' -Size 10 -Color '565656' -Align Center

# Table of contents style.
Style -Name 'TOC' -Size 16 -Color '005f4b'

# Table heading and row styles.
Style -Name 'TableDefaultHeading' -Size 10 -Color 'FAFAFA' -BackgroundColor '005f4b'
Style -Name 'TableDefaultRow' -Size 10 -Color '565656'
Style -Name 'TableDefaultAltRow' -Size 10 -Color '565656' -BackgroundColor 'F0F0F0'

# Table row/cell highlight styles.
Style -Name 'Critical' -Size 10 -Color '565656' -BackgroundColor 'FEDDD7'
Style -Name 'Warning' -Size 10 -Color '565656' -BackgroundColor 'FFF4C7'
Style -Name 'Info' -Size 10 -Color '565656' -BackgroundColor 'E3F5FC'
Style -Name 'OK' -Size 10 -Color '565656' -BackgroundColor 'DFF0D0'
Style -Name 'Ok' -Size 10 -Color '565656' -BackgroundColor 'DFF0D0'

# Table caption style.
Style -Name 'Caption' -Size 10 -Color '005f4b' -Italic -Align Left

# Veeam backup window/time-period styles.
Style -Name 'ON' -Size 8 -BackgroundColor 'DFF0D0' -Color DFF0D0
Style -Name 'OFF' -Size 8 -BackgroundColor 'FFF4C7' -Color FFF4C7

if ($Options.ReportStyle -eq 'Veeam') {
    $TableBorderColor = '005f4b'
} else {
    $TableBorderColor = '072E58'
}

$TableDefaultProperties = @{
    Id = 'TableDefault'
    HeaderStyle = 'TableDefaultHeading'
    RowStyle = 'TableDefaultRow'
    AlternateRowStyle = 'TableDefaultAltRow'
    BorderColor = $TableBorderColor
    Align = 'Left'
    CaptionStyle = 'Caption'
    CaptionLocation = 'Below'
    BorderWidth = 0.25
    PaddingTop = 1
    PaddingBottom = 1.5
    PaddingLeft = 2
    PaddingRight = 2
}

TableStyle @TableDefaultProperties -Default
TableStyle -Id 'Borderless' -HeaderStyle Normal -RowStyle Normal -BorderWidth 0
