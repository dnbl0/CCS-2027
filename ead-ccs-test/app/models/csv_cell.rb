# frozen_string_literal: true

# Makes a value safe to put in a CSV cell that someone will open in a spreadsheet (CSV injection, OWASP "CSV Injection"):
# Excel, Numbers and Sheets run a cell that starts with = + - @ as a formula (or, with a tab or carriage return first, can be
# tricked into one). Such a cell gets a leading apostrophe, which spreadsheets read as "this is text" and hide. A negative
# number or a date such as -1850 therefore reads as text too; that is the price of the guard, and it is rare in this data.
module CsvCell
  DANGEROUS_START = /\A[=+\-@\t\r]/

  def self.safe(value)
    text = value.to_s
    text.match?(DANGEROUS_START) ? "'#{text}" : text
  end
end
