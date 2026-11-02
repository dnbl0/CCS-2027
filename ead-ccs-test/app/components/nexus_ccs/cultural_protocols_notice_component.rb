# frozen_string_literal: true

module NexusCcs
  # Tells the visitor that cultural protocols apply to a record, on the record page (CCS-148). The access notice says only that
  # the asset is "available on request", and the sensitivity gate only that it may distress: neither says WHY an Indigenous
  # record is held back or who decides. This does, and points to Help (Indigenous Cultural Data and Access) and the collection team.
  #
  # It does not decide anything: AccessPolicy still decides what is shown (its ICIP and Community Restricted rules are unchanged),
  # and Sensitivity the gate. This component reads the same record fields to know when to speak. The wording is in
  # config/locales/en.yml (nexus_ccs.cultural_protocols) and is PLACEHOLDER wording until the University approves it.
  #
  #   ICIP Rights licence                 Indigenous Cultural and Intellectual Property: the community decides
  #   access condition Community Restricted   access limited to a community
  #   a restriction note saying "cultur..."  e.g. "Culturally sensitive images" (the collection staff's own words)
  class CulturalProtocolsNoticeComponent < ViewComponent::Base
    ICIP = /icip/i
    COMMUNITY_RESTRICTED = "community restricted"
    CULTURAL_NOTE = /\bcultur/i

    def initialize(document:)
      @document = document
    end

    def render? = reason.present?

    # :icip, :community or :cultural_note (the first that applies), or nil
    def reason
      @reason ||= if Array(@document["licence_type_ssim"]).any? { |licence| licence.to_s.match?(ICIP) } then :icip
      elsif Array(@document["access_condition_ssi"]).any? { |value| value.to_s.strip.casecmp?(COMMUNITY_RESTRICTED) } then :community
      elsif Array(@document["restrictions_tsi"]).any? { |note| note.to_s.match?(CULTURAL_NOTE) } then :cultural_note
      end
    end

    def title = t("nexus_ccs.cultural_protocols.title")
    def body = t("nexus_ccs.cultural_protocols.#{reason}")
  end
end
