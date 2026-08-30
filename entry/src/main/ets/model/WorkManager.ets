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
  versions?: WorkVersion[];
  chapters?: Chapter[];
  conversations?: Conversation[];
}

export interface WorkVersion {
  id: string;
  content: string;
  timestamp: string;
  changeNote?: string;
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

  private generateId(): string {
    return 'work_' + Date.now() + '_' + Math.random().toString(36).substring(2, 11);
  }

  private formatDate(date: Date): string {
    const pad = (n: number): string => n < 10 ? '0' + n : '' + n;
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ` +
      `${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }
}

export const workManager = new WorkManager();
