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

export enum ReauthenticationPurpose {
  RevealLargeSecret = 'revealLargeSecret',
  ExportData = 'exportData',
  ChangeCredential = 'changeCredential',
  PermanentDelete = 'permanentDelete',
  ExportDiagnostics = 'exportDiagnostics'
}

export enum SyncQueueOperation {
  Upload = 'upload',
  Download = 'download'
}

export interface SyncVersion {
  identifier: string;
  observedAt: number;
}

export interface SyncQueueItem {
  id: string;
  operation: SyncQueueOperation;
  localVersion: SyncVersion;
  remoteVersion?: SyncVersion;
  createdAt: number;
  attemptCount: number;
}

export interface SyncConflict {
  id: string;
  localVersion: SyncVersion;
  remoteVersion: SyncVersion;
  detectedAt: number;
}

export interface SyncActivity {
  id: string;
  state: SyncState;
  occurredAt: number;
  message: string;
}

// 条目模板类型无 KDBX 原生承载，存于条目 customData；取值沿用跨客户端草案拼写（PascalCase）。
export enum ItemTemplate {
  Login = 'Login',
  SecureNote = 'SecureNote',
  CreditCard = 'CreditCard',
  SshKey = 'SshKey',
  Attachment = 'Attachment',
  Password = 'Password'
}

// 条目模板类型键：跨客户端草案键名，不使用应用私有前缀。
export const LAYOUT_TYPE_KEY: string = 'KPEX_LayoutType'

// 未标记或取值非法一律返回 undefined：UI 按通用模板渲染，且不擅自回写类型。
export function itemTemplateFrom(value: string | undefined): ItemTemplate | undefined {
  switch (value) {
    case ItemTemplate.Login:
      return ItemTemplate.Login
    case ItemTemplate.SecureNote:
      return ItemTemplate.SecureNote
    case ItemTemplate.CreditCard:
      return ItemTemplate.CreditCard
    case ItemTemplate.SshKey:
      return ItemTemplate.SshKey
    case ItemTemplate.Attachment:
      return ItemTemplate.Attachment
    case ItemTemplate.Password:
      return ItemTemplate.Password
    default:
      return undefined
  }
}

export interface AuditFinding {
  id: string;
  severity: string;
  title: string;
  entryUuid: string;
  evidence: string;
}

// KDBX 保留字段名：条目标识与凭据走强类型属性，不进入自定义字段列表。
export const RESERVED_FIELD_NAMES: string[] = ['Title', 'UserName', 'Password', 'URL', 'Notes']

// 应用私有元数据（条目 customData）的键前缀，其他客户端会忽略。
export const META_KEY_PREFIX: string = 'KeePassHomo.'

// KDBX 无类型系统：类型由应用存于条目 customData，仅驱动输入控件与点击动作，落盘值一律为字符串。
export enum VaultFieldType {
  Text = 'text',
  Url = 'url',
  Email = 'email',
  Phone = 'phone',
  Address = 'address',
  Date = 'date',
  Password = 'password',
  Custom = 'custom'
}

export interface VaultField {
  name: string;
  protected: boolean;
  value: string;
  type: VaultFieldType;
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

  // 附件名与字节数；字节按需通过 loadAttachment 读取。
  attachments: VaultAttachmentMeta[];
  tags: string[];
  favorite: boolean;
  archived: boolean;

  // 未标记模板类型（其他客户端创建的条目）时为空，UI 按通用模板渲染。
  template: ItemTemplate | undefined;

  // 条目绑定了 KDBX 自定义图标（头像）；图标字节按需通过 loadEntryAvatar 读取。
  hasAvatar: boolean;
  lastModifiedAt: number;
}

export interface VaultFieldInput {
  name: string;
  value: string;
  type: VaultFieldType;
  protected: boolean;
}

export interface VaultAttachmentMeta {
  name: string;
  size: number;
}

// 一次保存期间要应用的附件变更：data 为空表示按名字删除附件。
export interface VaultAttachmentChange {
  name: string;
  data: ArrayBuffer | undefined;
}

export interface VaultEntryInput {
  groupUuid: string;
  title: string;
  username: string;
  password: string;
  url: string;
  notes: string;
  // 自定义字段：不含 5 个保留字段；未列出的既有自定义字段会被删除。
  fields: VaultFieldInput[];
  tags: string[];

  // 条目模板类型：仅创建时消费，更新不接收（类型新建即固定）。
  template?: ItemTemplate;

  // 头像三态：undefined 保持原有头像，null 删除头像，ArrayBuffer 写入该图片字节
  // （图标池中内容相同的项会被复用，否则新建）。
  avatar?: ArrayBuffer | null;
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
  // KDBX 回收站分组 uuid（meta.recycleBinUuid）；无回收站时为空串。
  recycleBinUuid: string;
}

export interface VaultEngine {
  identify(data: ArrayBuffer): VaultFormat;

  unlock(data: ArrayBuffer, credential: VaultCredential): Promise<VaultDocument>;

  create(name: string, credential: VaultCredential): Promise<VaultDocument>;

  createEntry(document: VaultDocument, input: VaultEntryInput): VaultEntry;

  updateEntry(document: VaultDocument, entryUuid: string, input: VaultEntryInput): VaultEntry;

  removeEntry(document: VaultDocument, entryUuid: string): void;

  // 父分组不存在时抛错。
  createGroup(document: VaultDocument, parentGroupUuid: string, name: string): VaultGroup;

  // 按 KDBX 语义把整棵子树（子分组与条目）移入回收站，回收站关闭时彻底移除；
  // 根分组是文档容器，不允许删除。
  removeGroup(document: VaultDocument, groupUuid: string): void;

  // 名称与该子树的 path 快照会同步更新。
  renameGroup(document: VaultDocument, groupUuid: string, name: string): VaultGroup;

  loadEntryAvatar(document: VaultDocument, entryUuid: string): ArrayBuffer | undefined;

  setEntryFavorite(document: VaultDocument, entryUuid: string, favorite: boolean): VaultEntry;

  setEntryArchived(document: VaultDocument, entryUuid: string, archived: boolean): VaultEntry;

  setEntryField(document: VaultDocument, entryUuid: string, name: string, value: string,
    protectedValue?: boolean): void;

  removeEntryField(document: VaultDocument, entryUuid: string, name: string): void;

  // 附件名在同一附件内唯一，重名由调用方保证；内容相同的二进制在库内按内容去重共享。
  loadAttachment(document: VaultDocument, entryUuid: string, name: string): ArrayBuffer;

  // 同条目内附件重名时自动加序号后缀，返回实际使用的附件名。
  addAttachment(document: VaultDocument, entryUuid: string, name: string,
    data: ArrayBuffer): Promise<VaultAttachmentMeta>;

  // 只解除条目引用；未被任何条目或历史引用的二进制在写入时回收。
  removeAttachment(document: VaultDocument, entryUuid: string, name: string): void;

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
