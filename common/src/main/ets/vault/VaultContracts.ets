export enum VaultSourceType {
  LocalFile = 'localFile',
  WebDav = 'webDav'
}

export enum VaultFormat {
  Kdbx31 = 'kdbx3.1',
  Kdbx4 = 'kdbx4',
  Unsupported = 'unsupported'
}

export interface VaultSource {
  type: VaultSourceType;
  uri: string;
  displayName: string;
  readOnly: boolean;
}

export interface VaultCredential {
  password: string;
  keyFile?: Uint8Array;
}

export enum SyncState {
  Idle = 'idle',
  Syncing = 'syncing',
  Synced = 'synced',
  Offline = 'offline',
  AuthRequired = 'authRequired',
  Error = 'error',
  Conflict = 'conflict'
}

export enum ConflictResolution {
  KeepLocal = 'keepLocal',
  UseRemote = 'useRemote',
  KeepBoth = 'keepBoth'
}

export enum ItemTemplate {
  Login = 'login',
  CreditCard = 'creditCard',
  SecureNote = 'secureNote',
  Identity = 'identity',
  Wifi = 'wifi',
  SoftwareLicense = 'softwareLicense'
}

export interface AuditFinding {
  id: string;
  severity: string;
  title: string;
  entryUuid: string;
  evidence: string;
}

export interface VaultField {
  name: string;
  protected: boolean;
  value: string;
}

export interface VaultEntry {
  uuid: string;
  title: string;
  groupUuid: string;
  groupName: string;
  groupPath: string;
  fields: VaultField[];
  historyCount: number;
  attachmentCount: number;
  tags: string[];
  favorite: boolean;
  archived: boolean;
  lastModifiedAt: number;
}

export interface VaultEntryInput {
  groupUuid: string;
  title: string;
  username: string;
  password: string;
  url: string;
  notes: string;
  tags: string[];
}

export interface VaultGroup {
  uuid: string;
  name: string;
  path: string;
  groups: VaultGroup[];
  entries: VaultEntry[];
}

export interface VaultDocument {
  format: VaultFormat;
  name: string;
  groups: VaultGroup[];
}

export interface VaultEngine {
  identify(data: ArrayBuffer): VaultFormat;

  unlock(data: ArrayBuffer, credential: VaultCredential): Promise<VaultDocument>;

  create(name: string, credential: VaultCredential): Promise<VaultDocument>;

  createEntry(document: VaultDocument, input: VaultEntryInput): VaultEntry;

  updateEntry(document: VaultDocument, entryUuid: string, input: VaultEntryInput): VaultEntry;

  setEntryFavorite(document: VaultDocument, entryUuid: string, favorite: boolean): VaultEntry;

  setEntryArchived(document: VaultDocument, entryUuid: string, archived: boolean): VaultEntry;

  setEntryField(document: VaultDocument, entryUuid: string, name: string, value: string,
    protectedValue?: boolean): void;

  removeEntryField(document: VaultDocument, entryUuid: string, name: string): void;

  write(document: VaultDocument): Promise<ArrayBuffer>;

  validate(data: ArrayBuffer, credential: VaultCredential): Promise<VaultDocument>;

  upgrade(document: VaultDocument): Promise<ArrayBuffer>;
}

export interface VaultRepository {
  read(source: VaultSource): Promise<ArrayBuffer>;

  persistAccess(source: VaultSource): Promise<void>;

  hasPersistentAccess(source: VaultSource): Promise<boolean>;

  activateAccess(source: VaultSource): Promise<void>;

  revokeAccess(source: VaultSource): Promise<void>;

  writeSafely(source: VaultSource, data: ArrayBuffer,
    validate: (candidate: ArrayBuffer) => Promise<void>): Promise<void>;

  backup(source: VaultSource, destinationUri: string): Promise<void>;

  relocate(source: VaultSource, destinationUri: string): Promise<VaultSource>;

  isWritable(source: VaultSource): boolean;
}

export interface VaultSession {
  readonly locked: boolean;
  readonly autoLockAfterMs: number;

  unlock(document: VaultDocument): void;

  lock(): void;

  touch(): void;

  shouldAutoLock(now?: number): boolean;

  reauthenticate(authenticate: () => Promise<void>): Promise<void>;

  clearSensitiveData(): void;

  getDocument(): VaultDocument;
}

export interface SyncService {
  readonly state: SyncState;

  compareRemote(source: VaultSource): Promise<SyncState>;

  upload(source: VaultSource, data: ArrayBuffer, remoteVersion: string): Promise<void>;

  download(source: VaultSource, remoteVersion: string): Promise<ArrayBuffer>;

  resolveConflict(resolution: ConflictResolution): Promise<void>;
}

export interface SecurityAuditService {
  audit(document: VaultDocument): Promise<AuditFinding[]>;
}
