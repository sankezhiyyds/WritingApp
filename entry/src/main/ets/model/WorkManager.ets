import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { TemplateInfo } from './TemplateModel';

export interface WorkItem {
  id: string;
  title: string;
  templateId: string;
  templateName: string;
  content: string;
  createTime: string;
  updateTime: string;
  archived?: boolean;
  workshop?: string; // 自由创作作品归属工作台：short_drama | novel
  versions?: WorkVersion[];
  chapters?: Chapter[];
  conversations?: Conversation[];
  outline?: OutlineNode[];
  characters?: CharacterInfo[];
  scenes?: SceneInfo[];
  coverColor?: string; // 封面颜色
  bgTheme?: string; // 背景主题：default | warm | cool | parchment
  folderId?: string; // 所属书架文件夹ID
  archiveFolderId?: string; // 所属旧档区文件夹ID
  aiContent?: string; // AI侧栏内容（与工作台内容分开保存）
}

/** 书架文件夹 */
export interface BookshelfFolder {
  id: string;
  name: string;
  coverColor: string;
  createTime: string;
  updateTime: string;
}

/** 旧档区文件夹 */
export interface ArchiveFolder {
  id: string;
  name: string;
  coverColor: string;
  createTime: string;
  updateTime: string;
}

/** 回收站条目（从书架/旧档删除的作品） */
export interface RecycleBinItem {
  id: string;
  originalWorkId: string;
  title: string;
  content: string;
  templateName: string;
  deleteTime: string;
  source: string; // bookshelf | archive
  originalFolderId?: string;
}

/** 中转站条目（跨设备/跨场景临时内容） */
export interface TransitItem {
  id: string;
  title: string;
  content: string;
  source: string; // 来源设备或场景标识
  createTime: string;
  expireDays: number; // 过期天数（默认7天）
}

/** 灵感池条目（原子化服务卡片快速记录） */
export interface InspirationItem {
  id: string;
  content: string;
  category: string; // idea | snippet | note
  createTime: string;
  fromWidget: boolean; // 是否来自桌面卡片
  deviceId?: string; // 来源设备
}

export interface WorkVersion {
  id: string;
  content: string;
  timestamp: string;
  changeNote?: string;
}

/** 大纲树节点 */
export interface OutlineNode {
  id: string;
  title: string;
  content: string;
  parentId: string;       // 空字符串表示根节点
  level: number;          // 0=卷, 1=章, 2=节
  order: number;          // 同级排序
  collapsed: boolean;     // 子节点是否折叠
}

/** 角色信息 */
export interface CharacterInfo {
  id: string;
  name: string;
  role: string;           // 主角/配角/反派/路人
  description: string;
  personality: string;
  appearance: string;
  background: string;
}

/** 场景信息 */
export interface SceneInfo {
  id: string;
  title: string;
  location: string;
  time: string;
  summary: string;
  characters: string;     // 涉及角色名，逗号分隔
  order: number;
}

export interface Chapter {
  id: string;
  title: string;
  category: string;
  content: string;
  order: number;
  createTime: string;
  updateTime: string;
}

export interface Conversation {
  id: string;
  userMessage: string;
  aiResponse: string;
  timestamp: string;
  savedAsDocument?: boolean;
}

export class WorkManager {
  private works: WorkItem[] = [];
  private folders: BookshelfFolder[] = [];
  private archiveFolders: ArchiveFolder[] = [];
  private recycleBinItems: RecycleBinItem[] = [];
  private transitItems: TransitItem[] = [];
  private inspirationItems: InspirationItem[] = [];
  private storageKey: string = 'writing_app_works';
  private folderKey: string = 'writing_app_folders';
  private archiveFolderKey: string = 'writing_app_archive_folders';
  private recycleBinKey: string = 'writing_app_recycle_bin';
  private transitKey: string = 'writing_app_transit';
  private inspirationKey: string = 'writing_app_inspirations';
  private prefs: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  private changeListeners: Array<() => void> = [];
  private saveQueue: Promise<void> = Promise.resolve();

  /** 订阅作品数据变化（增删改/归档），返回取消订阅函数 */
  onChange(callback: () => void): () => void {
    this.changeListeners.push(callback);
    return () => {
      this.changeListeners = this.changeListeners.filter(fn => fn !== callback);
    };
  }

  private notifyChange(): void {
    for (let i = 0; i < this.changeListeners.length; i++) {
      this.changeListeners[i]();
    }
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    try {
      this.prefs = await preferences.getPreferences(context, 'writing_app');
      await this.loadFromStorage();
    } catch (e) {
      console.error('[WorkManager] 初始化失败: ' + JSON.stringify(e));
    }
  }

  private async loadFromStorage(): Promise<void> {
    if (!this.prefs) return;
    try {
      const stored = await this.prefs.get(this.storageKey, '') as string;
      if (stored) {
        const parsed = JSON.parse(stored) as WorkItem[];
        if (Array.isArray(parsed)) {
          this.works = parsed;
        }
      }
      // 加载书架文件夹
      const folderStored = await this.prefs.get(this.folderKey, '') as string;
      if (folderStored) {
        const folderParsed = JSON.parse(folderStored) as BookshelfFolder[];
        if (Array.isArray(folderParsed)) {
          this.folders = folderParsed;
        }
      }
      // 加载旧档区文件夹
      const archiveFolderStored = await this.prefs.get(this.archiveFolderKey, '') as string;
      if (archiveFolderStored) {
        const archiveFolderParsed = JSON.parse(archiveFolderStored) as ArchiveFolder[];
        if (Array.isArray(archiveFolderParsed)) {
          this.archiveFolders = archiveFolderParsed;
        }
      }
      // 加载回收站
      const recycleStored = await this.prefs.get(this.recycleBinKey, '') as string;
      if (recycleStored) {
        const recycleParsed = JSON.parse(recycleStored) as RecycleBinItem[];
        if (Array.isArray(recycleParsed)) {
          this.recycleBinItems = recycleParsed;
        }
      }
      // 加载中转站
      const transitStored = await this.prefs.get(this.transitKey, '') as string;
      if (transitStored) {
        const transitParsed = JSON.parse(transitStored) as TransitItem[];
        if (Array.isArray(transitParsed)) {
          this.transitItems = transitParsed;
        }
      }
      // 加载灵感池
      const inspirationStored = await this.prefs.get(this.inspirationKey, '') as string;
      if (inspirationStored) {
        const inspirationParsed = JSON.parse(inspirationStored) as InspirationItem[];
        if (Array.isArray(inspirationParsed)) {
          this.inspirationItems = inspirationParsed;
        }
      }
    } catch (e) {
      console.error('[WorkManager] 读取数据失败: ' + JSON.stringify(e));
    }
  }

  /** 保存并序列化，避免并发覆盖 */
  private async saveToStorage(): Promise<void> {
    // 立即通知UI刷新，不等异步存储完成
    this.notifyChange();
    this.saveQueue = this.saveQueue.then(async () => {
      if (!this.prefs) return;
      try {
        await this.prefs.put(this.storageKey, JSON.stringify(this.works));
        await this.prefs.put(this.folderKey, JSON.stringify(this.folders));
        await this.prefs.put(this.archiveFolderKey, JSON.stringify(this.archiveFolders));
        await this.prefs.put(this.recycleBinKey, JSON.stringify(this.recycleBinItems));
        await this.prefs.put(this.transitKey, JSON.stringify(this.transitItems));
        await this.prefs.put(this.inspirationKey, JSON.stringify(this.inspirationItems));
        await this.prefs.flush();
      } catch (e) {
        console.error('[WorkManager] 保存数据失败: ' + JSON.stringify(e));
      }
    });
    return this.saveQueue;
  }

  createWork(template: TemplateInfo, title: string, content: string): WorkItem {
    const now = new Date();
    const work: WorkItem = {
      id: this.generateId(),
      title: title,
      templateId: template.id,
      templateName: template.name,
      content: content,
      createTime: this.formatDate(now),
      updateTime: this.formatDate(now),
      versions: [],
      chapters: [],
      conversations: []
    };
    this.works.unshift(work);
    this.saveToStorage();
    return work;
  }

  /** 自由创作（不依赖模板），workshop 指定归属工作台 */
  createFreeWork(title: string, content: string, workshop: string): WorkItem {
    const now = new Date();
    const work: WorkItem = {
      id: this.generateId(),
      title: title,
      templateId: 'free',
      templateName: '自由创作',
      content: content,
      createTime: this.formatDate(now),
      updateTime: this.formatDate(now),
      workshop: workshop,
      versions: [],
      chapters: [],
      conversations: []
    };
    this.works.unshift(work);
    this.saveToStorage();
    return work;
  }

  updateWork(workId: string, content: string, autoArchive: boolean = true): WorkItem | null {
    const work = this.works.find(w => w.id === workId);
    if (work) {
      // 自动归档旧版本
      if (autoArchive && work.content !== content && work.content.trim().length > 0) {
        const version: WorkVersion = {
          id: this.generateId(),
          content: work.content,
          timestamp: this.formatDate(new Date()),
          changeNote: '自动保存'
        };
        if (!work.versions) work.versions = [];
        work.versions.unshift(version);
        // 只保留最近20个版本
        if (work.versions.length > 20) {
          work.versions = work.versions.slice(0, 20);
        }
      }
      work.content = content;
      work.updateTime = this.formatDate(new Date());
      this.saveToStorage();
    }
    return work || null;
  }

  /** 更新作品标题 */
  updateTitle(workId: string, title: string): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work) {
      work.title = title;
      work.updateTime = this.formatDate(new Date());
      this.saveToStorage();
      return true;
    }
    return false;
  }

  /** 恢复到指定历史版本（当前内容先归档为新版本） */
  restoreVersion(workId: string, versionId: string): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work && work.versions) {
      const version = work.versions.find(v => v.id === versionId);
      if (version) {
        if (work.content.trim().length > 0) {
          const backup: WorkVersion = {
            id: this.generateId(),
            content: work.content,
            timestamp: this.formatDate(new Date()),
            changeNote: '版本恢复前自动备份'
          };
          work.versions.unshift(backup);
          if (work.versions.length > 20) {
            work.versions = work.versions.slice(0, 20);
          }
        }
        work.content = version.content;
        work.updateTime = this.formatDate(new Date());
        this.saveToStorage();
        return true;
      }
    }
    return false;
  }

  addChapter(workId: string, title: string, category: string, content: string): Chapter | null {
    const work = this.works.find(w => w.id === workId);
    if (work) {
      const now = this.formatDate(new Date());
      const chapter: Chapter = {
        id: this.generateId(),
        title: title,
        category: category,
        content: content,
        order: work.chapters ? work.chapters.length : 0,
        createTime: now,
        updateTime: now
      };
      if (!work.chapters) work.chapters = [];
      work.chapters.push(chapter);
      work.updateTime = now;
      this.saveToStorage();
      return chapter;
    }
    return null;
  }

  updateChapter(workId: string, chapterId: string, content: string): Chapter | null {
    const work = this.works.find(w => w.id === workId);
    if (work && work.chapters) {
      const chapter = work.chapters.find(c => c.id === chapterId);
      if (chapter) {
        chapter.content = content;
        chapter.updateTime = this.formatDate(new Date());
        work.updateTime = chapter.updateTime;
        this.saveToStorage();
        return chapter;
      }
    }
    return null;
  }

  deleteChapter(workId: string, chapterId: string): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work && work.chapters) {
      const index = work.chapters.findIndex(c => c.id === chapterId);
      if (index !== -1) {
        work.chapters.splice(index, 1);
        work.updateTime = this.formatDate(new Date());
        this.saveToStorage();
        return true;
      }
    }
    return false;
  }

  addConversation(workId: string, userMessage: string, aiResponse: string): Conversation | null {
    const work = this.works.find(w => w.id === workId);
    if (work) {
      const conversation: Conversation = {
        id: this.generateId(),
        userMessage: userMessage,
        aiResponse: aiResponse,
        timestamp: this.formatDate(new Date()),
        savedAsDocument: false
      };
      if (!work.conversations) work.conversations = [];
      work.conversations.push(conversation);
      work.updateTime = conversation.timestamp;
      this.saveToStorage();
      return conversation;
    }
    return null;
  }

  saveConversationAsDocument(workId: string, conversationId: string, documentType: 'thought_chain' | 'final_plan'): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work && work.conversations) {
      const conversation = work.conversations.find(c => c.id === conversationId);
      if (conversation) {
        conversation.savedAsDocument = true;
        // 创建章节保存文档
        const category = documentType === 'thought_chain' ? '思维链路' : '最终方案';
        const title = `${category}_${conversation.timestamp.replace(/[:\s]/g, '')}`;
        const content = `用户: ${conversation.userMessage}\n\nAI: ${conversation.aiResponse}`;
        const chapter = this.addChapter(workId, title, category, content);
        if (chapter) {
          return true;
        }
        return false;
      }
    }
    return false;
  }

  deleteWork(workId: string): boolean {
    const index = this.works.findIndex(w => w.id === workId);
    if (index !== -1) {
      this.works.splice(index, 1);
      this.saveToStorage();
      return true;
    }
    return false;
  }

  /** 重命名作品 */
  renameWork(workId: string, newTitle: string): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work) {
      work.title = newTitle;
      work.updateTime = new Date().toISOString();
      this.saveToStorage();
      return true;
    }
    return false;
  }

  /** 更换作品封面颜色 */
  changeWorkCover(workId: string, coverColor: string): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work) {
      work.coverColor = coverColor;
      work.updateTime = new Date().toISOString();
      this.saveToStorage();
      return true;
    }
    return false;
  }

  getWork(workId: string): WorkItem | null {
    return this.works.find(w => w.id === workId) || null;
  }

  getAllWorks(): WorkItem[] {
    return this.works;
  }

  getWorksByTemplate(templateId: string): WorkItem[] {
    return this.works.filter(w => w.templateId === templateId);
  }

  /** 书架：未归档的作品 */
  getBookshelfWorks(): WorkItem[] {
    return this.works.filter(w => !w.archived);
  }

  /** 获取书架文件夹中的作品 */
  getWorksByFolder(folderId: string): WorkItem[] {
    return this.works.filter(w => !w.archived && w.folderId === folderId);
  }

  /** 获取未分类的书架作品 */
  getUnfiledBookshelfWorks(): WorkItem[] {
    return this.works.filter(w => !w.archived && !w.folderId);
  }

  /** 旧档区：已归档的作品 */
  getArchivedWorks(): WorkItem[] {
    return this.works.filter(w => w.archived);
  }

  /** 获取旧档区文件夹中的作品 */
  getArchivedWorksByFolder(folderId: string): WorkItem[] {
    return this.works.filter(w => w.archived && w.archiveFolderId === folderId);
  }

  /** 获取未分类的旧档区作品 */
  getUnfiledArchivedWorks(): WorkItem[] {
    return this.works.filter(w => w.archived && !w.archiveFolderId);
  }

  /** 归档作品（移入旧档区，可选择文件夹） */
  archiveWork(workId: string, archiveFolderId?: string): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work) {
      work.archived = true;
      work.archiveFolderId = archiveFolderId;
      work.updateTime = this.formatDate(new Date());
      this.saveToStorage();
      return true;
    }
    return false;
  }

  /** 取消归档（移回书架） */
  unarchiveWork(workId: string): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work) {
      work.archived = false;
      work.archiveFolderId = undefined;
      work.updateTime = this.formatDate(new Date());
      this.saveToStorage();
      return true;
    }
    return false;
  }

  // ===== 书架文件夹管理 =====

  /** 获取所有书架文件夹 */
  getFolders(): BookshelfFolder[] {
    return this.folders;
  }

  /** 创建书架文件夹 */
  createFolder(name: string, coverColor: string = '#FF2D55'): BookshelfFolder {
    const folder: BookshelfFolder = {
      id: this.generateId(),
      name: name,
      coverColor: coverColor,
      createTime: this.formatDate(new Date()),
      updateTime: this.formatDate(new Date())
    };
    this.folders.push(folder);
    this.saveToStorage();
    return folder;
  }

  /** 重命名书架文件夹 */
  renameFolder(folderId: string, name: string): boolean {
    const folder = this.folders.find(f => f.id === folderId);
    if (folder) {
      folder.name = name;
      folder.updateTime = this.formatDate(new Date());
      this.saveToStorage();
      return true;
    }
    return false;
  }

  /** 更改文件夹封面颜色 */
  changeFolderCover(folderId: string, coverColor: string): boolean {
    const folder = this.folders.find(f => f.id === folderId);
    if (folder) {
      folder.coverColor = coverColor;
      folder.updateTime = this.formatDate(new Date());
      this.saveToStorage();
      return true;
    }
    return false;
  }

  /** 删除书架文件夹（作品变为未分类） */
  deleteFolder(folderId: string): boolean {
    const index = this.folders.findIndex(f => f.id === folderId);
    if (index !== -1) {
      // 将文件夹内的作品设为未分类
      for (const work of this.works) {
        if (work.folderId === folderId) {
          work.folderId = undefined;
        }
      }
      this.folders.splice(index, 1);
      this.saveToStorage();
      return true;
    }
    return false;
  }

  /** 将作品移入书架文件夹 */
  moveWorkToFolder(workId: string, folderId: string): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work) {
      work.folderId = folderId;
      work.updateTime = this.formatDate(new Date());
      this.saveToStorage();
      return true;
    }
    return false;
  }

  // ===== 旧档区文件夹管理 =====

  /** 获取所有旧档区文件夹 */
  getArchiveFolders(): ArchiveFolder[] {
    return this.archiveFolders;
  }

  /** 创建旧档区文件夹 */
  createArchiveFolder(name: string, coverColor: string = '#6B7280'): ArchiveFolder {
    const folder: ArchiveFolder = {
      id: this.generateId(),
      name: name,
      coverColor: coverColor,
      createTime: this.formatDate(new Date()),
      updateTime: this.formatDate(new Date())
    };
    this.archiveFolders.push(folder);
    this.saveToStorage();
    return folder;
  }

  /** 重命名旧档区文件夹 */
  renameArchiveFolder(folderId: string, name: string): boolean {
    const folder = this.archiveFolders.find(f => f.id === folderId);
    if (folder) {
      folder.name = name;
      folder.updateTime = this.formatDate(new Date());
      this.saveToStorage();
      return true;
    }
    return false;
  }

  /** 更改旧档区文件夹封面颜色 */
  changeArchiveFolderCover(folderId: string, coverColor: string): boolean {
    const folder = this.archiveFolders.find(f => f.id === folderId);
    if (folder) {
      folder.coverColor = coverColor;
      folder.updateTime = this.formatDate(new Date());
      this.saveToStorage();
      return true;
    }
    return false;
  }

  /** 删除旧档区文件夹（作品变为未分类） */
  deleteArchiveFolder(folderId: string): boolean {
    const index = this.archiveFolders.findIndex(f => f.id === folderId);
    if (index !== -1) {
      for (const work of this.works) {
        if (work.archiveFolderId === folderId) {
          work.archiveFolderId = undefined;
        }
      }
      this.archiveFolders.splice(index, 1);
      this.saveToStorage();
      return true;
    }
    return false;
  }

  /** 更新作品的AI侧栏内容 */
  updateAiContent(workId: string, aiContent: string): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work) {
      work.aiContent = aiContent;
      work.updateTime = this.formatDate(new Date());
      this.saveToStorage();
      return true;
    }
    return false;
  }

  /** 导出全部作品为JSON字符串 */
  exportAll(): string {
    return JSON.stringify(this.works);
  }

  /** 从备份JSON导入作品，返回导入数量（跳过重复id） */
  importWorks(json: string): number {
    try {
      const parsed = JSON.parse(json) as WorkItem[];
      if (!Array.isArray(parsed)) {
        return 0;
      }
      let count = 0;
      for (let i = 0; i < parsed.length; i++) {
        const item = parsed[i];
        if (item && item.id && !this.works.some(w => w.id === item.id)) {
          this.works.push(item);
          count++;
        }
      }
      if (count > 0) {
        this.saveToStorage();
      }
      return count;
    } catch (e) {
      console.error('[WorkManager] 导入作品失败: ' + JSON.stringify(e));
      return 0;
    }
  }

  private generateId(): string {
    return 'work_' + Date.now() + '_' + Math.random().toString(36).substring(2, 11);
  }

  private formatDate(date: Date): string {
    const pad = (n: number): string => n < 10 ? '0' + n : '' + n;
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ` +
      `${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  // ==================== 大纲树管理 ====================

  addOutlineNode(workId: string, title: string, parentId: string, level: number): OutlineNode | null {
    const work = this.works.find(w => w.id === workId);
    if (!work) return null;
    if (!work.outline) work.outline = [];

    const siblings = work.outline.filter(n => n.parentId === parentId);
    const order = siblings.length;
    const node: OutlineNode = {
      id: this.generateId(),
      title: title,
      content: '',
      parentId: parentId,
      level: level,
      order: order,
      collapsed: false
    };
    work.outline.push(node);
    work.updateTime = this.formatDate(new Date());
    this.saveToStorage();
    return node;
  }

  updateOutlineNode(workId: string, nodeId: string, title: string, content: string): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work && work.outline) {
      const node = work.outline.find(n => n.id === nodeId);
      if (node) {
        node.title = title;
        node.content = content;
        work.updateTime = this.formatDate(new Date());
        this.saveToStorage();
        return true;
      }
    }
    return false;
  }

  deleteOutlineNode(workId: string, nodeId: string): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work && work.outline) {
      // 递归删除子节点
      const toDelete: string[] = [nodeId];
      let changed = true;
      while (changed) {
        changed = false;
        for (let i = 0; i < work.outline.length; i++) {
          const node = work.outline[i];
          if (toDelete.includes(node.parentId) && !toDelete.includes(node.id)) {
            toDelete.push(node.id);
            changed = true;
          }
        }
      }
      work.outline = work.outline.filter(n => !toDelete.includes(n.id));
      work.updateTime = this.formatDate(new Date());
      this.saveToStorage();
      return true;
    }
    return false;
  }

  toggleOutlineCollapsed(workId: string, nodeId: string): void {
    const work = this.works.find(w => w.id === workId);
    if (work && work.outline) {
      const node = work.outline.find(n => n.id === nodeId);
      if (node) {
        node.collapsed = !node.collapsed;
        this.saveToStorage();
      }
    }
  }

  moveOutlineNode(workId: string, nodeId: string, direction: 'up' | 'down'): void {
    const work = this.works.find(w => w.id === workId);
    if (work && work.outline) {
      const node = work.outline.find(n => n.id === nodeId);
      if (!node) return;
      const siblings = work.outline.filter(n => n.parentId === node.parentId).sort((a, b) => a.order - b.order);
      const index = siblings.findIndex(n => n.id === nodeId);
      if (direction === 'up' && index > 0) {
        const prev = siblings[index - 1];
        const tempOrder = node.order;
        node.order = prev.order;
        prev.order = tempOrder;
      } else if (direction === 'down' && index < siblings.length - 1) {
        const next = siblings[index + 1];
        const tempOrder = node.order;
        node.order = next.order;
        next.order = tempOrder;
      }
      this.saveToStorage();
    }
  }

  // ==================== 角色管理 ====================

  addCharacter(workId: string, name: string, role: string): CharacterInfo | null {
    const work = this.works.find(w => w.id === workId);
    if (!work) return null;
    if (!work.characters) work.characters = [];
    const char: CharacterInfo = {
      id: this.generateId(),
      name: name,
      role: role,
      description: '',
      personality: '',
      appearance: '',
      background: ''
    };
    work.characters.push(char);
    work.updateTime = this.formatDate(new Date());
    this.saveToStorage();
    return char;
  }

  updateCharacter(workId: string, charId: string, updates: Partial<CharacterInfo>): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work && work.characters) {
      const char = work.characters.find(c => c.id === charId);
      if (char) {
        if (updates.name !== undefined) char.name = updates.name;
        if (updates.role !== undefined) char.role = updates.role;
        if (updates.description !== undefined) char.description = updates.description;
        if (updates.personality !== undefined) char.personality = updates.personality;
        if (updates.appearance !== undefined) char.appearance = updates.appearance;
        if (updates.background !== undefined) char.background = updates.background;
        work.updateTime = this.formatDate(new Date());
        this.saveToStorage();
        return true;
      }
    }
    return false;
  }

  deleteCharacter(workId: string, charId: string): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work && work.characters) {
      const index = work.characters.findIndex(c => c.id === charId);
      if (index !== -1) {
        work.characters.splice(index, 1);
        work.updateTime = this.formatDate(new Date());
        this.saveToStorage();
        return true;
      }
    }
    return false;
  }

  // ==================== 场景管理 ====================

  addScene(workId: string, title: string): SceneInfo | null {
    const work = this.works.find(w => w.id === workId);
    if (!work) return null;
    if (!work.scenes) work.scenes = [];
    const scene: SceneInfo = {
      id: this.generateId(),
      title: title,
      location: '',
      time: '',
      summary: '',
      characters: '',
      order: work.scenes.length
    };
    work.scenes.push(scene);
    work.updateTime = this.formatDate(new Date());
    this.saveToStorage();
    return scene;
  }

  updateScene(workId: string, sceneId: string, updates: Partial<SceneInfo>): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work && work.scenes) {
      const scene = work.scenes.find(s => s.id === sceneId);
      if (scene) {
        if (updates.title !== undefined) scene.title = updates.title;
        if (updates.location !== undefined) scene.location = updates.location;
        if (updates.time !== undefined) scene.time = updates.time;
        if (updates.summary !== undefined) scene.summary = updates.summary;
        if (updates.characters !== undefined) scene.characters = updates.characters;
        work.updateTime = this.formatDate(new Date());
        this.saveToStorage();
        return true;
      }
    }
    return false;
  }

  deleteScene(workId: string, sceneId: string): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work && work.scenes) {
      const index = work.scenes.findIndex(s => s.id === sceneId);
      if (index !== -1) {
        work.scenes.splice(index, 1);
        work.updateTime = this.formatDate(new Date());
        this.saveToStorage();
        return true;
      }
    }
    return false;
  }

  // ==================== 素材库：回收站 ====================

  /** 移入回收站 */
  moveToRecycleBin(workId: string, source: string = 'bookshelf'): boolean {
    const work = this.works.find(w => w.id === workId);
    if (!work) return false;
    const item: RecycleBinItem = {
      id: this.generateId(),
      originalWorkId: work.id,
      title: work.title,
      content: work.content,
      templateName: work.templateName,
      deleteTime: this.formatDate(new Date()),
      source: source,
      originalFolderId: work.folderId
    };
    this.recycleBinItems.push(item);
    // 从works中移除
    this.works = this.works.filter(w => w.id !== workId);
    this.saveToStorage();
    return true;
  }

  /** 从回收站恢复 */
  restoreFromRecycleBin(recycleId: string): boolean {
    const item = this.recycleBinItems.find(r => r.id === recycleId);
    if (!item) return false;
    // 恢复为works
    const restoredWork: WorkItem = {
      id: item.originalWorkId,
      title: item.title,
      templateId: '',
      templateName: item.templateName,
      content: item.content,
      createTime: this.formatDate(new Date()),
      updateTime: this.formatDate(new Date()),
      folderId: item.originalFolderId || ''
    };
    this.works.push(restoredWork);
    this.recycleBinItems = this.recycleBinItems.filter(r => r.id !== recycleId);
    this.saveToStorage();
    return true;
  }

  /** 彻底删除回收站条目 */
  deleteFromRecycleBin(recycleId: string): boolean {
    const before = this.recycleBinItems.length;
    this.recycleBinItems = this.recycleBinItems.filter(r => r.id !== recycleId);
    if (this.recycleBinItems.length !== before) {
      this.saveToStorage();
      return true;
    }
    return false;
  }

  /** 清空回收站 */
  clearRecycleBin(): void {
    this.recycleBinItems = [];
    this.saveToStorage();
  }

  /** 获取回收站列表 */
  getRecycleBinItems(): RecycleBinItem[] {
    return this.recycleBinItems;
  }

  // ==================== 素材库：中转站 ====================

  /** 添加中转站条目 */
  addToTransit(title: string, content: string, source: string = 'local', expireDays: number = 7): TransitItem {
    const item: TransitItem = {
      id: this.generateId(),
      title: title,
      content: content,
      source: source,
      createTime: this.formatDate(new Date()),
      expireDays: expireDays
    };
    this.transitItems.push(item);
    this.saveToStorage();
    return item;
  }

  /** 获取中转站列表（自动过滤过期） */
  getTransitItems(): TransitItem[] {
    const now = new Date();
    this.transitItems = this.transitItems.filter(item => {
      const created = new Date(item.createTime);
      const diffDays = (now.getTime() - created.getTime()) / (1000 * 60 * 60 * 24);
      return diffDays <= item.expireDays;
    });
    return this.transitItems;
  }

  /** 从中转站移除 */
  removeFromTransit(transitId: string): boolean {
    const before = this.transitItems.length;
    this.transitItems = this.transitItems.filter(t => t.id !== transitId);
    if (this.transitItems.length !== before) {
      this.saveToStorage();
      return true;
    }
    return false;
  }

  /** 清空中转站 */
  clearTransit(): void {
    this.transitItems = [];
    this.saveToStorage();
  }

  // ==================== 素材库：灵感池 ====================

  /** 添加灵感 */
  addInspiration(content: string, category: string = 'idea', fromWidget: boolean = false, deviceId?: string): InspirationItem {
    const item: InspirationItem = {
      id: this.generateId(),
      content: content,
      category: category,
      createTime: this.formatDate(new Date()),
      fromWidget: fromWidget,
      deviceId: deviceId
    };
    this.inspirationItems.push(item);
    this.saveToStorage();
    return item;
  }

  /** 获取灵感池列表 */
  getInspirations(): InspirationItem[] {
    return this.inspirationItems;
  }

  /** 删除灵感 */
  deleteInspiration(inspirationId: string): boolean {
    const before = this.inspirationItems.length;
    this.inspirationItems = this.inspirationItems.filter(i => i.id !== inspirationId);
    if (this.inspirationItems.length !== before) {
      this.saveToStorage();
      return true;
    }
    return false;
  }

  /** 更新灵感内容 */
  updateInspiration(inspirationId: string, content: string): boolean {
    const item = this.inspirationItems.find(i => i.id === inspirationId);
    if (item) {
      item.content = content;
      this.saveToStorage();
      return true;
    }
    return false;
  }
}

export const workManager = new WorkManager();
