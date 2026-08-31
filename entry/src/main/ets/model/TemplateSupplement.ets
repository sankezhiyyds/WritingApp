import { TemplateInfo } from './TemplateModel';

// ========== 补充模板：缺失品类 ==========
export const supplementTemplates: TemplateInfo[] = [

  // ===== 交互/沉浸类 =====
  {
    id: 'transmigration',
    name: '穿书互动剧本',
    icon: '🌀',
    desc: '穿书/穿越互动叙事，读者代入角色影响剧情走向',
    category: '交互沉浸类',
    color: '#8B5CF6',
    fields: [
      { key: 'bookTitle', label: '原作名称', type: 'text', required: true, placeholder: '被穿入的原作书名' },
      { key: 'role', label: '穿越角色', type: 'text', required: true, placeholder: '主角穿越后成为谁' },
      { key: 'entryPoint', label: '穿入节点', type: 'textarea', required: true, placeholder: '穿入原作的哪个时间节点' },
      { key: 'goal', label: '核心目标', type: 'textarea', required: true, placeholder: '穿越者的核心目的' },
      { key: 'branches', label: '分支设计', type: 'textarea', required: false, placeholder: '关键抉择点和可能分支' },
      { key: 'metaKnowledge', label: 'meta知识', type: 'textarea', required: false, placeholder: '穿越者拥有的原作剧情信息' }
    ],
    format: '【穿书设定】\n原作：{{bookTitle}}\n穿越角色：{{role}}\n穿入节点：{{entryPoint}}\n核心目标：{{goal}}\n\n【分支路线】\n{{branches}}\n\n【Meta知识】\n{{metaKnowledge}}',
    tips: ['穿入节点要选在剧情转折前', 'Meta知识是双刃剑', '分支设计至少3条路线']
  },
  {
    id: 'roleplay_setting',
    name: '角色扮演设定',
    icon: '🎭',
    desc: 'AI角色扮演世界观设定，含人设锁定和行为规则',
    category: '交互沉浸类',
    color: '#7C3AED',
    fields: [
      { key: 'worldName', label: '世界名称', type: 'text', required: true, placeholder: '故事发生的虚构世界名' },
      { key: 'era', label: '时代背景', type: 'text', required: true, placeholder: '古代/现代/未来/架空' },
      { key: 'rules', label: '世界规则', type: 'textarea', required: true, placeholder: '核心法则' },
      { key: 'npcList', label: 'NPC列表', type: 'textarea', required: false, placeholder: '重要NPC及其性格' },
      { key: 'taboo', label: '禁忌设定', type: 'textarea', required: false, placeholder: '不允许发生的事' }
    ],
    format: '【世界观】\n世界：{{worldName}} | 时代：{{era}}\n规则：{{rules}}\n\n【NPC】\n{{npcList}}\n\n【禁忌】\n{{taboo}}',
    tips: ['世界规则要自洽', 'NPC性格要鲜明', '禁忌设定增加沉浸感']
  },
  {
    id: 'parallel_world',
    name: '平行宇宙设定',
    icon: '🌌',
    desc: '平行宇宙/多元世界框架，适合科幻和奇幻长篇',
    category: '交互沉浸类',
    color: '#6366F1',
    fields: [
      { key: 'universeCount', label: '宇宙数量', type: 'number', required: true, placeholder: '平行宇宙数量' },
      { key: 'divergence', label: '分歧点', type: 'textarea', required: true, placeholder: '各宇宙与主宇宙的关键分歧' },
      { key: 'travel', label: '穿越机制', type: 'textarea', required: true, placeholder: '宇宙间穿越的规则和代价' },
      { key: 'conflict', label: '跨宇宙冲突', type: 'textarea', required: false, placeholder: '不同宇宙间的矛盾' }
    ],
    format: '【平行宇宙框架】\n数量：{{universeCount}}个宇宙\n\n【分歧点】\n{{divergence}}\n\n【穿越机制】\n{{travel}}\n\n【跨宇宙冲突】\n{{conflict}}',
    tips: ['每个宇宙需有独特标识', '穿越代价要明确', '跨宇宙冲突是故事张力来源']
  },
  {
    id: 'multi_ending',
    name: '多结局分支剧本',
    icon: '🔀',
    desc: '多结局叙事结构，含分支树和结局条件',
    category: '交互沉浸类',
    color: '#A855F7',
    fields: [
      { key: 'mainPlot', label: '主线剧情', type: 'textarea', required: true, placeholder: '贯穿始终的主线' },
      { key: 'branchPoints', label: '分支点', type: 'textarea', required: true, placeholder: '关键抉择点' },
      { key: 'endings', label: '结局设计', type: 'textarea', required: true, placeholder: '各结局的触发条件和内容' },
      { key: 'endingCount', label: '结局数量', type: 'number', required: true, placeholder: '总结局数' }
    ],
    format: '【主线】\n{{mainPlot}}\n\n【分支点】\n{{branchPoints}}\n\n【结局（{{endingCount}}个）】\n{{endings}}',
    tips: ['结局要有好/中/坏多种类型', '分支点要影响后续走向', '避免假分支']
  },

  // ===== 世界观专项 =====
  {
    id: 'geo_setting',
    name: '地理地图设定',
    icon: '🗺️',
    desc: '故事地理空间设定，含地图、区域、地标',
    category: '世界观专项',
    color: '#059669',
    fields: [
      { key: 'mapName', label: '地图名称', type: 'text', required: true, placeholder: '世界/大陆/城市名' },
      { key: 'regions', label: '区域划分', type: 'textarea', required: true, placeholder: '各区域名称、特点、气候' },
      { key: 'landmarks', label: '重要地标', type: 'textarea', required: false, placeholder: '关键地点及其故事意义' },
      { key: 'distances', label: '距离关系', type: 'textarea', required: false, placeholder: '各地标间距离和旅行时间' }
    ],
    format: '【地理设定】\n地图：{{mapName}}\n\n【区域】\n{{regions}}\n\n【地标】\n{{landmarks}}\n\n【距离】\n{{distances}}',
    tips: ['地理逻辑要自洽', '地标要有故事功能', '距离影响剧情节奏']
  },
  {
    id: 'history_timeline',
    name: '历史年表',
    icon: '📜',
    desc: '虚构世界历史编年，含大事件和因果链',
    category: '世界观专项',
    color: '#0891B2',
    fields: [
      { key: 'eraName', label: '纪元名称', type: 'text', required: true, placeholder: '如：第一纪元' },
      { key: 'majorEvents', label: '重大事件', type: 'textarea', required: true, placeholder: '按时间顺序列出重大历史事件' },
      { key: 'causes', label: '因果链', type: 'textarea', required: false, placeholder: '事件之间的因果关系' },
      { key: 'impact', label: '对现世影响', type: 'textarea', required: false, placeholder: '历史如何影响当前故事' }
    ],
    format: '【{{eraName}}年表】\n\n【重大事件】\n{{majorEvents}}\n\n【因果链】\n{{causes}}\n\n【对现世影响】\n{{impact}}',
    tips: ['历史要有因果逻辑', '留白比写满更好', '历史影响当前剧情才有意义']
  },
  {
    id: 'magic_system',
    name: '魔法/科技体系',
    icon: '⚡',
    desc: '超自然/科技规则体系，含能力分级和限制',
    category: '世界观专项',
    color: '#0D9488',
    fields: [
      { key: 'systemName', label: '体系名称', type: 'text', required: true, placeholder: '如：灵气体系' },
      { key: 'levels', label: '能力分级', type: 'textarea', required: true, placeholder: '从低到高的能力等级' },
      { key: 'cost', label: '使用代价', type: 'textarea', required: true, placeholder: '使用能力的代价/限制' },
      { key: 'source', label: '力量来源', type: 'textarea', required: false, placeholder: '能力从何而来' },
      { key: 'taboo', label: '禁忌', type: 'textarea', required: false, placeholder: '不可触碰的禁区' }
    ],
    format: '【{{systemName}}】\n\n【能力分级】\n{{levels}}\n\n【使用代价】\n{{cost}}\n\n【力量来源】\n{{source}}\n\n【禁忌】\n{{taboo}}',
    tips: ['局限性决定难题难度', '代价要真实可感', '分级要有质变']
  },
  {
    id: 'faction_network',
    name: '势力关系网',
    icon: '🕸️',
    desc: '多方势力博弈设定，含关系矩阵和利益冲突',
    category: '世界观专项',
    color: '#10B981',
    fields: [
      { key: 'factions', label: '势力列表', type: 'textarea', required: true, placeholder: '各方势力名称及特点' },
      { key: 'relations', label: '关系矩阵', type: 'textarea', required: true, placeholder: '势力间关系' },
      { key: 'conflicts', label: '核心冲突', type: 'textarea', required: false, placeholder: '势力间的主要矛盾' },
      { key: 'balance', label: '势力平衡', type: 'textarea', required: false, placeholder: '当前势力平衡状态' }
    ],
    format: '【势力关系网】\n\n【势力】\n{{factions}}\n\n【关系】\n{{relations}}\n\n【冲突】\n{{conflicts}}\n\n【平衡】\n{{balance}}',
    tips: ['至少3方势力才有博弈空间', '关系要动态变化', '平衡打破是剧情推动力']
  },

  // ===== 人物专项 =====
  {
    id: 'character_graph',
    name: '人物关系图谱',
    icon: '👥',
    desc: '角色间关系可视化设定，含关系类型和变化',
    category: '人物专项',
    color: '#F59E0B',
    fields: [
      { key: 'characters', label: '角色列表', type: 'textarea', required: true, placeholder: '所有角色姓名及身份' },
      { key: 'relations', label: '关系定义', type: 'textarea', required: true, placeholder: '每对角色的关系类型' },
      { key: 'evolution', label: '关系演变', type: 'textarea', required: false, placeholder: '关系如何随剧情变化' },
      { key: 'secrets', label: '隐藏关系', type: 'textarea', required: false, placeholder: '角色间不为人知的关系' }
    ],
    format: '【人物关系图谱】\n\n【角色】\n{{characters}}\n\n【关系】\n{{relations}}\n\n【演变】\n{{evolution}}\n\n【隐藏】\n{{secrets}}',
    tips: ['关系要有层次', '隐藏关系是反转素材', '关系演变推动角色成长']
  },
  {
    id: 'character_arc',
    name: '角色成长弧',
    icon: '📈',
    desc: '角色心理成长轨迹，含起点、转折和终点',
    category: '人物专项',
    color: '#F97316',
    fields: [
      { key: 'character', label: '角色名', type: 'text', required: true, placeholder: '角色姓名' },
      { key: 'startState', label: '初始状态', type: 'textarea', required: true, placeholder: '故事开始时的状态' },
      { key: 'catalyst', label: '催化事件', type: 'textarea', required: true, placeholder: '触发改变的关键事件' },
      { key: 'struggle', label: '挣扎过程', type: 'textarea', required: false, placeholder: '新旧自我之间的冲突' },
      { key: 'endState', label: '终点状态', type: 'textarea', required: true, placeholder: '故事结束时的成长结果' }
    ],
    format: '【{{character}}的成长弧】\n\n【起点】{{startState}}\n\n【催化】{{catalyst}}\n\n【挣扎】{{struggle}}\n\n【终点】{{endState}}',
    tips: ['成长不是突变', '催化事件要有冲击力', '终点与起点形成对比']
  },
  {
    id: 'dialogue_style',
    name: '对话风格模板',
    icon: '💬',
    desc: '角色语言风格设定，含口头禅和表达习惯',
    category: '人物专项',
    color: '#EAB308',
    fields: [
      { key: 'character', label: '角色名', type: 'text', required: true, placeholder: '角色姓名' },
      { key: 'tone', label: '语气基调', type: 'select', required: true, placeholder: '选择语气', options: ['活泼', '沉稳', '尖刻', '温柔', '豪迈', '阴沉', '学究', '市井'] },
      { key: 'habits', label: '语言习惯', type: 'textarea', required: true, placeholder: '口头禅、常用句式' },
      { key: 'vocabulary', label: '词汇偏好', type: 'textarea', required: false, placeholder: '常用/回避的词汇' },
      { key: 'sample', label: '示例对话', type: 'textarea', required: false, placeholder: '写2-3句典型台词' }
    ],
    format: '【{{character}}对话风格】\n语气：{{tone}}\n习惯：{{habits}}\n词汇：{{vocabulary}}\n\n【示例】\n{{sample}}',
    tips: ['对话要能听出是谁说的', '口头禅不要过度使用', '语气随情境变化']
  },

  // ===== 时间线专项 =====
  {
    id: 'timeline_editor',
    name: '时间线编辑器',
    icon: '⏱️',
    desc: '故事事件时间排列，含并行线和交叉点',
    category: '时间线专项',
    color: '#3B82F6',
    fields: [
      { key: 'storyName', label: '故事名', type: 'text', required: true, placeholder: '故事/作品名' },
      { key: 'timeSpan', label: '时间跨度', type: 'text', required: true, placeholder: '如：三个月/十年' },
      { key: 'mainLine', label: '主线事件', type: 'textarea', required: true, placeholder: '按时间顺序列出主线事件' },
      { key: 'subLines', label: '支线事件', type: 'textarea', required: false, placeholder: '并行支线的时间线' },
      { key: 'crossPoints', label: '交叉点', type: 'textarea', required: false, placeholder: '主线与支线的交汇时刻' }
    ],
    format: '【{{storyName}}时间线】\n跨度：{{timeSpan}}\n\n【主线】\n{{mainLine}}\n\n【支线】\n{{subLines}}\n\n【交叉】\n{{crossPoints}}',
    tips: ['时间线要标注具体时间点', '支线不能与主线矛盾', '交叉点是高潮时刻']
  },
  {
    id: 'pacing_chart',
    name: '情节节奏表',
    icon: '📊',
    desc: '故事节奏规划，含张弛曲线和高潮分布',
    category: '时间线专项',
    color: '#2563EB',
    fields: [
      { key: 'totalChapters', label: '总章节数', type: 'number', required: true, placeholder: '预计总章节' },
      { key: 'actStructure', label: '幕结构', type: 'select', required: true, placeholder: '选择结构', options: ['三幕式', '四幕式', '五幕式', '网文连载'] },
      { key: 'tensionCurve', label: '张力曲线', type: 'textarea', required: true, placeholder: '各章节的紧张度变化' },
      { key: 'climax', label: '高潮位置', type: 'textarea', required: true, placeholder: '主要高潮的章节位置' },
      { key: 'breathers', label: '缓冲段落', type: 'textarea', required: false, placeholder: '高潮间的休息段落' }
    ],
    format: '【节奏规划】\n总章节：{{totalChapters}}\n结构：{{actStructure}}\n\n【张力曲线】\n{{tensionCurve}}\n\n【高潮】\n{{climax}}\n\n【缓冲】\n{{breathers}}',
    tips: ['张弛有度才能留住读者', '高潮前需要铺垫', '缓冲段不是废段，要推进支线']
  },
  {
    id: 'foreshadow_mgr',
    name: '伏笔管理系统',
    icon: '🪤',
    desc: '伏笔埋设与回收追踪，避免烂尾',
    category: '时间线专项',
    color: '#1D4ED8',
    fields: [
      { key: 'foreshadows', label: '伏笔列表', type: 'textarea', required: true, placeholder: '所有伏笔及埋设章节' },
      { key: 'payoffs', label: '回收计划', type: 'textarea', required: true, placeholder: '每条伏笔的回收章节和方式' },
      { key: 'status', label: '当前状态', type: 'textarea', required: false, placeholder: '已埋/已回/待回' },
      { key: 'redHerrings', label: '红鲱鱼', type: 'textarea', required: false, placeholder: '误导性伏笔' }
    ],
    format: '【伏笔管理】\n\n【伏笔】\n{{foreshadows}}\n\n【回收计划】\n{{payoffs}}\n\n【状态】\n{{status}}\n\n【红鲱鱼】\n{{redHerrings}}',
    tips: ['每条伏笔都要有回收计划', '回收间隔不要太长', '红鲱鱼要有叙事功能']
  },

  // ===== 写作工具 =====
  {
    id: 'hook_design',
    name: '钩子设计模板',
    icon: '🪝',
    desc: '章节开头/结尾钩子设计，提升追读率',
    category: '写作工具',
    color: '#EF4444',
    fields: [
      { key: 'chapterNum', label: '章节号', type: 'number', required: true, placeholder: '章节编号' },
      { key: 'openingHook', label: '开头钩子', type: 'textarea', required: true, placeholder: '章节开头3行内抓住读者' },
      { key: 'endingHook', label: '结尾钩子', type: 'textarea', required: true, placeholder: '章节结尾留下悬念' },
      { key: 'hookType', label: '钩子类型', type: 'select', required: true, placeholder: '选择类型', options: ['悬念', '反转', '危机', '揭秘', '情感', '冲突'] }
    ],
    format: '【第{{chapterNum}}章钩子】\n类型：{{hookType}}\n\n【开头】\n{{openingHook}}\n\n【结尾】\n{{endingHook}}',
    tips: ['开头3行定生死', '结尾钩子决定追读率', '钩子要与前文有因果']
  },
  {
    id: 'shuangdian',
    name: '爽点分析模板',
    icon: '🔥',
    desc: '网文爽点节奏设计，含打脸和升级节点',
    category: '写作工具',
    color: '#DC2626',
    fields: [
      { key: 'genre', label: '类型', type: 'select', required: true, placeholder: '选择类型', options: ['都市', '玄幻', '科幻', '历史', '言情', '悬疑'] },
      { key: 'shuangdianList', label: '爽点列表', type: 'textarea', required: true, placeholder: '按章节列出爽点事件' },
      { key: 'dadian', label: '打脸设计', type: 'textarea', required: false, placeholder: '打脸前后的反差' },
      { key: 'upgrade', label: '升级节奏', type: 'textarea', required: false, placeholder: '主角实力/地位升级节点' }
    ],
    format: '【爽点分析】\n类型：{{genre}}\n\n【爽点】\n{{shuangdianList}}\n\n【打脸】\n{{dadian}}\n\n【升级】\n{{upgrade}}',
    tips: ['爽点间隔不超过3章', '打脸要有铺垫', '升级要有实质变化']
  },
  {
    id: 'retention_opt',
    name: '追读率优化',
    icon: '🎯',
    desc: '章节留存率分析和优化建议',
    category: '写作工具',
    color: '#B91C1C',
    fields: [
      { key: 'weakChapters', label: '流失章节', type: 'textarea', required: true, placeholder: '读者流失较多的章节' },
      { key: 'reason', label: '流失原因', type: 'textarea', required: true, placeholder: '分析流失原因' },
      { key: 'fix', label: '优化方案', type: 'textarea', required: true, placeholder: '针对每个流失点的改进' },
      { key: 'abTest', label: 'A/B方案', type: 'textarea', required: false, placeholder: '可对比的替代写法' }
    ],
    format: '【追读率优化】\n\n【流失章节】\n{{weakChapters}}\n\n【原因】\n{{reason}}\n\n【优化】\n{{fix}}\n\n【A/B测试】\n{{abTest}}',
    tips: ['流失点通常在铺垫段', '优化不是加爽点而是改节奏', 'A/B测试验证效果']
  },

  // ===== 创意引擎 =====
  {
    id: 'random_inspire',
    name: '随机灵感发生器',
    icon: '💡',
    desc: '随机元素组合生成创意种子',
    category: '创意引擎',
    color: '#FBBF24',
    fields: [
      { key: 'elementCount', label: '元素数量', type: 'number', required: true, placeholder: '随机组合的元素数' },
      { key: 'categories', label: '元素类别', type: 'textarea', required: true, placeholder: '如：人物+场景+冲突+道具' },
      { key: 'constraints', label: '约束条件', type: 'textarea', required: false, placeholder: '限制条件' },
      { key: 'output', label: '生成结果', type: 'textarea', required: false, placeholder: 'AI生成的灵感组合' }
    ],
    format: '【灵感发生器】\n元素数：{{elementCount}}\n类别：{{categories}}\n约束：{{constraints}}\n\n【结果】\n{{output}}',
    tips: ['元素越不相关越有创意', '约束激发创造力', '多生成几组选最好的']
  },
  {
    id: 'brainstorm_board',
    name: '脑暴白板',
    icon: '🧠',
    desc: '自由发散思维整理，含分类和筛选',
    category: '创意引擎',
    color: '#F59E0B',
    fields: [
      { key: 'topic', label: '主题', type: 'text', required: true, placeholder: '脑暴主题' },
      { key: 'ideas', label: '想法列表', type: 'textarea', required: true, placeholder: '所有发散想法' },
      { key: 'filter', label: '筛选标准', type: 'textarea', required: false, placeholder: '筛选好想法的标准' },
      { key: 'selected', label: '入选想法', type: 'textarea', required: false, placeholder: '筛选后的优质想法' }
    ],
    format: '【脑暴：{{topic}}】\n\n【所有想法】\n{{ideas}}\n\n【筛选标准】\n{{filter}}\n\n【入选】\n{{selected}}',
    tips: ['先量后质', '不要过早否定', '组合想法产生新创意']
  },
  {
    id: 'rhetoric_template',
    name: '修辞手法模板',
    icon: '✍️',
    desc: '修辞技巧应用示范，含场景和效果',
    category: '创意引擎',
    color: '#D97706',
    fields: [
      { key: 'rhetoricType', label: '修辞类型', type: 'select', required: true, placeholder: '选择修辞', options: ['比喻', '拟人', '排比', '对比', '夸张', '通感', '借代', '反讽'] },
      { key: 'scene', label: '适用场景', type: 'textarea', required: true, placeholder: '什么情节适合用此修辞' },
      { key: 'example', label: '示范段落', type: 'textarea', required: true, placeholder: '写一段应用此修辞的文字' },
      { key: 'effect', label: '效果分析', type: 'textarea', required: false, placeholder: '此修辞达到的效果' }
    ],
    format: '【{{rhetoricType}}】\n\n【场景】{{scene}}\n\n【示范】\n{{example}}\n\n【效果】{{effect}}',
    tips: ['修辞服务内容不要炫技', '同一段不要堆砌多种修辞', '效果要可感知']
  },

  // ===== 出版/分享 =====
  {
    id: 'synopsis_template',
    name: '作品简介模板',
    icon: '📖',
    desc: '作品简介/内容提要，含吸引力和信息量',
    category: '出版分享',
    color: '#6B7280',
    fields: [
      { key: 'title', label: '作品名', type: 'text', required: true, placeholder: '作品标题' },
      { key: 'genre', label: '类型', type: 'text', required: true, placeholder: '作品类型' },
      { key: 'wordCount', label: '字数', type: 'number', required: true, placeholder: '预计/已完成字数' },
      { key: 'synopsis', label: '简介正文', type: 'textarea', required: true, placeholder: '200-500字内容简介' },
      { key: 'tags', label: '标签', type: 'text', required: false, placeholder: '用逗号分隔的标签' }
    ],
    format: '《{{title}}》\n类型：{{genre}} | 字数：{{wordCount}}\n标签：{{tags}}\n\n{{synopsis}}',
    tips: ['简介前50字最关键', '不要剧透核心反转', '标签要精准']
  },
  {
    id: 'copyright_notice',
    name: '版权声明模板',
    icon: '©️',
    desc: '作品版权声明和授权说明',
    category: '出版分享',
    color: '#4B5563',
    fields: [
      { key: 'workTitle', label: '作品名', type: 'text', required: true, placeholder: '作品标题' },
      { key: 'author', label: '作者', type: 'text', required: true, placeholder: '作者/笔名' },
      { key: 'license', label: '授权类型', type: 'select', required: true, placeholder: '选择授权', options: ['独家', '非独家', 'CC BY', 'CC BY-NC', '保留所有权利'] },
      { key: 'date', label: '日期', type: 'text', required: true, placeholder: '声明日期' }
    ],
    format: '版权声明\n\n作品：《{{workTitle}}》\n作者：{{author}}\n授权：{{license}}\n日期：{{date}}\n\n未经许可不得转载、改编或商用。',
    tips: ['明确授权范围', '保留修改权', '注明日期']
  },
  {
    id: 'submission_letter',
    name: '投稿信模板',
    icon: '📧',
    desc: '向平台/出版社投稿的 Cover Letter',
    category: '出版分享',
    color: '#374151',
    fields: [
      { key: 'recipient', label: '收件方', type: 'text', required: true, placeholder: '平台/出版社/编辑名' },
      { key: 'workTitle', label: '作品名', type: 'text', required: true, placeholder: '投稿作品名' },
      { key: 'wordCount', label: '字数', type: 'number', required: true, placeholder: '作品字数' },
      { key: 'pitch', label: '一句话推介', type: 'textarea', required: true, placeholder: '用一句话概括作品亮点' },
      { key: 'bio', label: '作者简介', type: 'textarea', required: false, placeholder: '简短作者介绍' }
    ],
    format: '尊敬的{{recipient}}：\n\n现向贵方投稿作品《{{workTitle}}》（约{{wordCount}}字）。\n\n{{pitch}}\n\n作者简介：{{bio}}\n\n期待您的回复。',
    tips: ['推介要抓人', '字数要准确', '附上前3章试读']
  }
];
