module Collections
  # The EMu export went through a spreadsheet that read Grainger accession numbers as decimals, so 00.0070 arrived as
  # 0.007 and 01.0011 as 1.0011. Grainger numbers are always a two-digit year and a four-digit number (NN.NNNN), so
  # the lost zeros can be put back. Numbers with more parts (01.3524.1) or words (01.0422 RETIRED) were kept as text
  # by the export, and other collections' numbers have another shape, so both are left alone.
  module AccessionNumber
    GRAINGER = "Grainger Museum Collection".freeze
    DECIMAL = /\A(\d{1,2})\.(\d{1,4})\z/

    def self.restore(number, collection)
      return number unless collection == GRAINGER && (match = DECIMAL.match(number))

      "#{match[1].rjust(2, "0")}.#{match[2].ljust(4, "0")}"
    end
  end
end
