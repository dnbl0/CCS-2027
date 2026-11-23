# frozen_string_literal: true

# The Cite records page of a list or of the saved records (CCS-137): the visitor picks a style and the records to cite
# (all of them to begin with), sees the citations Citation builds (titles in italics), copies them, or downloads them as a Word
# document that keeps the italics (WordDocument, the story's "export (word doc)") or as plain text. One address serves all three:
# the page, and the same address as .docx or .txt. The controllers say which records.
module CitationsPage
  extend ActiveSupport::Concern

  private

  def render_citations(documents, heading:, back_path:, back_label:)
    @cite_documents = documents
    @cite_style = Citation.style_from(params[:style])
    @cite_submitted = params[:submitted].present?
    ids = Array(params[:ids]).map(&:to_s)
    @cite_selected = @cite_submitted || ids.any? ? documents.select { |document| ids.include?(document.id.to_s) } : documents
    sources = @cite_selected.map { |document| Citation.source_for(document, url: solr_document_url(document)) }
    @cite_texts = Citation.reference_list(sources, @cite_style, accessed: Date.current)
    @cite_runs = Citation.reference_runs(sources, @cite_style, accessed: Date.current)
    @cite_heading = heading
    @cite_back_path = back_path
    @cite_back_label = back_label

    respond_to do |format|
      format.html { render "citations/show" }
      format.docx do
        word = WordDocument.new(heading: Citation.list_heading(@cite_style), paragraphs: @cite_runs)
        send_data word.to_s, type: WordDocument::MIME_TYPE, disposition: "attachment", filename: "citations-#{@cite_style}.docx"
      end
      format.text do
        send_data @cite_texts.join("\n\n") << "\n", type: "text/plain; charset=utf-8", disposition: "attachment",
                                                    filename: "citations-#{@cite_style}.txt"
      end
    end
  end
end
