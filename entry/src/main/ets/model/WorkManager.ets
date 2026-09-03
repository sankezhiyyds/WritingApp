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
  private storageKey: string = 'writing_app_works';
  private prefs: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  private changeListeners: Array<() => void> = [];

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
    } catch (e) {
      console.error('[WorkManager] 读取作品失败: ' + JSON.stringify(e));
    }
  }

  private async saveToStorage(): Promise<void> {
    if (!this.prefs) return;
    try {
      await this.prefs.put(this.storageKey, JSON.stringify(this.works));
      await this.prefs.flush();
      this.notifyChange();
    } catch (e) {
      console.error('[WorkManager] 保存作品失败: ' + JSON.stringify(e));
    }
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
        this.addChapter(workId, title, category, content);
        this.saveToStorage();
        return true;
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

  /** 旧档区：已归档的作品 */
  getArchivedWorks(): WorkItem[] {
    return this.works.filter(w => w.archived);
  }

  /** 归档作品（移入旧档区） */
  archiveWork(workId: string): boolean {
    const work = this.works.find(w => w.id === workId);
    if (work) {
      work.archived = true;
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
        for (const node of work.outline) {
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
}

export const workManager = new WorkManager();
