export type VocabularyOwnershipScope =
  | "platform_canonical"
  | "tenant_extension";

export type VocabularyPublicationStatus =
  | "draft"
  | "in_review"
  | "verified"
  | "certified"
  | "published"
  | "deprecated"
  | "withdrawn";

export type CoreWordRecord = {
  id: string;
  canonicalCode: string;
  ownershipScope: VocabularyOwnershipScope;
  organizationId: string | null;
  lemma: string;
  lexicalIdentityKey: string;
  displayWord: string;
  languageCode: string;
  primaryPartOfSpeech: string;
  primaryGradeBand: string | null;
  firstInstructionGrade: number | null;
  tier: 1 | 2 | 3 | null;
  studentDefinition: string | null;
  academicDefinition: string | null;
  pronunciationText: string | null;
  syllabification: string | null;
  syllableCount: number | null;
  primaryStress: string | null;
  academicClassification: string | null;
  fastBridgeClassification: string | null;
  satBridgeClassification: string | null;
  publicationStatus: VocabularyPublicationStatus;
  versionNumber: number;
  createdAt: string;
  createdBy: string | null;
  updatedAt: string;
  updatedBy: string | null;
};

export type SenseRecord = {
  id: string;
  wordId: string;
  senseKey: string;
  senseNumber: number;
  studentDefinition: string;
  academicDefinition: string | null;
  disciplineScope: string | null;
  gradeMin: number | null;
  gradeMax: number | null;
  usageLabel: string | null;
  exampleText: string | null;
  nonExampleText: string | null;
  precisionNote: string | null;
  publicationStatus: VocabularyPublicationStatus;
  versionNumber: number;
  createdAt: string;
  createdBy: string | null;
  updatedAt: string;
  updatedBy: string | null;
};

export function isPlatformCanonicalWord(
  word: Pick<CoreWordRecord, "ownershipScope" | "organizationId">,
) {
  return word.ownershipScope === "platform_canonical" && word.organizationId === null;
}

export function isTenantVocabularyExtension(
  word: Pick<CoreWordRecord, "ownershipScope" | "organizationId">,
) {
  return word.ownershipScope === "tenant_extension" && word.organizationId !== null;
}
