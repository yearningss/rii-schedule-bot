//
//  ScheduleWidget.swift
//  ScheduleWidgetExtension
//
//  Нативный виджет расписания для iOS (WidgetKit + SwiftUI)
//

import WidgetKit
import SwiftUI

// Модель элемента расписания для виджета
struct ParaModel {
    let num: Int
    let startMin: Int
    let endMin: Int
    let timeStr: String
    let subject: String
    let aud: String
    let teacher: String
    let type: String
}

// Запись таймлайна виджета
struct ScheduleEntry: TimelineEntry {
    let date: Date
    let groupName: String
    let dateFormatted: String
    let dayOfWeek: String
    let weekText: String
    let statusText: String
    let isLive: Bool
    
    // Текущая пара
    let currentNum: Int?
    let currentSubject: String
    let currentAud: String
    let currentTeacher: String
    let currentTime: String
    
    // Следующая пара
    let nextNum: Int?
    let nextSubject: String
    let nextAud: String
    let nextTime: String
    let nextStatus: String
}

// Провайдер данных виджета
struct ScheduleProvider: TimelineProvider {
    
    private let bellTimes: [Int: (Int, Int)] = [
        1: (510, 600),   // 08:30 - 10:00
        2: (610, 700),   // 10:10 - 11:40
        3: (730, 820),   // 12:10 - 13:40
        4: (830, 920),   // 13:50 - 15:20
        5: (930, 1020),  // 15:30 - 17:00
        6: (1030, 1120)  // 17:10 - 18:40
    ]
    
    private let bellStrings: [Int: String] = [
        1: "08:30 - 10:00",
        2: "10:10 - 11:40",
        3: "12:10 - 13:40",
        4: "13:50 - 15:20",
        5: "15:30 - 17:00",
        6: "17:10 - 18:40"
    ]
    
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(
            date: Date(),
            groupName: "РИИ",
            dateFormatted: "1 Сен",
            dayOfWeek: "Пн",
            weekText: "I неделя",
            statusText: "Расписание занятий",
            isLive: false,
            currentNum: 1,
            currentSubject: "Высшая математика",
            currentAud: "Ауд. 214",
            currentTeacher: "Иванов И.И.",
            currentTime: "08:30 - 10:00",
            nextNum: 2,
            nextSubject: "Информатика",
            nextAud: "Ауд. 308",
            nextTime: "10:10 - 11:40",
            nextStatus: "В 10:10"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        completion(createEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let currentDate = Date()
        let entry = createEntry(for: currentDate)
        
        // Обновление каждые 15 минут
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate.addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    // Расчет состояния расписания
    private func createEntry(for date: Date) -> ScheduleEntry {
        let sharedDefaults = UserDefaults(suiteName: "group.com.yearnings.riiSchedule") ?? UserDefaults.standard
        let groupName = sharedDefaults.string(forKey: "group_name") ?? "РИИ"
        let subgroup = sharedDefaults.integer(forKey: "subgroup")
        let jsonStr = sharedDefaults.string(forKey: "widget_schedule_json") ?? ""
        
        // Часовой пояс Барнаул/Рубцовск (UTC+7)
        let timeZone = TimeZone(identifier: "Asia/Barnaul") ?? TimeZone(secondsFromGMT: 7 * 3600)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        
        let components = calendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let curMins = hour * 60 + minute
        let weekday = components.weekday ?? 2 // 1 = Sunday, 2 = Monday...
        
        // Конвертация в формат Пн=1..Вс=7
        let rDay = (weekday == 1) ? 7 : (weekday - 1)
        
        let dayNames = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
        let curDayStr = (rDay >= 1 && rDay <= 7) ? dayNames[rDay - 1] : "Пн"
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = timeZone
        formatter.dateFormat = "d MMM"
        let dateFormatted = formatter.string(from: date)
        
        if jsonStr.isEmpty {
            return ScheduleEntry(
                date: date,
                groupName: groupName,
                dateFormatted: dateFormatted,
                dayOfWeek: curDayStr,
                weekText: "РИИ",
                statusText: "Откройте приложение",
                isLive: false,
                currentNum: nil,
                currentSubject: "Расписание не загружено",
                currentAud: "",
                currentTeacher: "",
                currentTime: "",
                nextNum: nil,
                nextSubject: "",
                nextAud: "",
                nextTime: "",
                nextStatus: "Нажмите для входа"
            )
        }
        
        guard let data = jsonStr.data(using: .utf8),
              let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return placeholder(in: Context())
        }
        
        var weekNumber = jsonObj["weekNumber"] as? Int ?? 1
        let scheduleData = jsonObj["scheduleData"] as? [String: Any] ?? [:]
        
        var targetDay = rDay
        var isSunday = (rDay == 7)
        var isRollover = false
        
        // В воскресенье показываем понедельник следующей недели
        if isSunday {
            targetDay = 1
            weekNumber = (weekNumber == 1) ? 2 : 1
            isRollover = true
        }
        
        var paras = parseParas(from: scheduleData, day: targetDay, subgroup: subgroup)
        
        // В субботу, если пар нет, показываем понедельник следующей недели
        if rDay == 6 && paras.isEmpty {
            targetDay = 1
            weekNumber = (weekNumber == 1) ? 2 : 1
            isRollover = true
            paras = parseParas(from: scheduleData, day: 1, subgroup: subgroup)
        }
        
        let weekText = (weekNumber == 2) ? "II неделя" : "I неделя"
        
        if paras.isEmpty {
            return ScheduleEntry(
                date: date,
                groupName: groupName,
                dateFormatted: dateFormatted,
                dayOfWeek: curDayStr,
                weekText: weekText,
                statusText: isRollover ? "Выходной день" : "Пар нет",
                isLive: false,
                currentNum: nil,
                currentSubject: isRollover ? "Занятия начнутся в Пн" : "На сегодня занятий нет",
                currentAud: "",
                currentTeacher: "",
                currentTime: "",
                nextNum: nil,
                nextSubject: "",
                nextAud: "",
                nextTime: "",
                nextStatus: "Отдыхайте"
            )
        }
        
        if isRollover {
            let firstP = paras[0]
            return ScheduleEntry(
                date: date,
                groupName: groupName,
                dateFormatted: dateFormatted,
                dayOfWeek: curDayStr,
                weekText: weekText,
                statusText: "В понедельник к \(firstP.startMin / 60):\(String(format: "%02d", firstP.startMin % 60))",
                isLive: false,
                currentNum: nil,
                currentSubject: "Выходной день",
                currentAud: "",
                currentTeacher: "",
                currentTime: "",
                nextNum: firstP.num,
                nextSubject: firstP.subject,
                nextAud: firstP.aud,
                nextTime: firstP.timeStr,
                nextStatus: "Первая пара в Пн"
            )
        }
        
        // Поиск текущей и следующей пары
        var curP: ParaModel? = nil
        var nextP: ParaModel? = nil
        var statusText = ""
        var isLive = false
        var nextStatus = ""
        
        let firstP = paras.first!
        let lastP = paras.last!
        
        if curMins < firstP.startMin {
            let diff = firstP.startMin - curMins
            statusText = "До начала: \(diff) мин"
            nextP = firstP
            nextStatus = "Начало в \(firstP.timeStr.components(separatedBy: " - ").first ?? "")"
        } else if curMins >= lastP.endMin {
            statusText = "Пары завершены"
            curP = nil
            nextP = nil
            nextStatus = "Все пары на сегодня закончились"
        } else {
            for (idx, p) in paras.enumerated() {
                if curMins >= p.startMin && curMins < p.endMin {
                    curP = p
                    isLive = true
                    let left = p.endMin - curMins
                    statusText = "Идет пара (осталось \(left) мин)"
                    if idx + 1 < paras.count {
                        nextP = paras[idx + 1]
                    }
                    break
                } else if curMins < p.startMin {
                    nextP = p
                    let breakTime = p.startMin - curMins
                    statusText = "Перемена (\(breakTime) мин)"
                    nextStatus = "След. пара в \(p.timeStr.components(separatedBy: " - ").first ?? "")"
                    break
                }
            }
        }
        
        return ScheduleEntry(
            date: date,
            groupName: groupName,
            dateFormatted: dateFormatted,
            dayOfWeek: curDayStr,
            weekText: weekText,
            statusText: statusText,
            isLive: isLive,
            currentNum: curP?.num,
            currentSubject: curP?.subject ?? (nextP != nil ? "Сейчас перемена" : "Пар нет"),
            currentAud: curP?.aud ?? "",
            currentTeacher: curP?.teacher ?? "",
            currentTime: curP?.timeStr ?? "",
            nextNum: nextP?.num,
            nextSubject: nextP?.subject ?? "",
            nextAud: nextP?.aud ?? "",
            nextTime: nextP?.timeStr ?? "",
            nextStatus: nextStatus
        )
    }
    
    private func parseParas(from scheduleData: [String: Any], day: Int, subgroup: Int) -> [ParaModel] {
        guard let dayObj = scheduleData[String(day)] as? [String: Any] else {
            return []
        }
        
        var list: [ParaModel] = []
        for pNum in 1...6 {
            guard let pObj = dayObj[String(pNum)] as? [String: Any] else { continue }
            let times = bellTimes[pNum] ?? (0, 0)
            let isDouble = pObj["isDouble"] as? Bool ?? false
            
            var subj = ""
            var aud = ""
            var teacher = ""
            var pType = ""
            
            if !isDouble {
                subj = pObj["subj1"] as? String ?? ""
                aud = pObj["aud1"] as? String ?? ""
                teacher = pObj["teacher1"] as? String ?? ""
                pType = pObj["type1"] as? String ?? ""
            } else {
                if subgroup == 2 {
                    subj = (pObj["subj2"] as? String)?.isEmpty == false ? (pObj["subj2"] as! String) : (pObj["subj1"] as? String ?? "")
                    aud = (pObj["aud2"] as? String)?.isEmpty == false ? (pObj["aud2"] as! String) : (pObj["aud1"] as? String ?? "")
                    teacher = (pObj["teacher2"] as? String)?.isEmpty == false ? (pObj["teacher2"] as! String) : (pObj["teacher1"] as? String ?? "")
                    pType = (pObj["type2"] as? String)?.isEmpty == false ? (pObj["type2"] as! String) : (pObj["type1"] as? String ?? "")
                } else {
                    subj = pObj["subj1"] as? String ?? ""
                    aud = pObj["aud1"] as? String ?? ""
                    teacher = pObj["teacher1"] as? String ?? ""
                    pType = pObj["type1"] as? String ?? ""
                }
            }
            
            subj = subj.trimmingCharacters(in: .whitespacesAndNewlines)
            if !subj.isEmpty {
                var audStr = ""
                if !aud.isEmpty {
                    audStr = "Ауд. " + aud
                }
                list.append(
                    ParaModel(
                        num: pNum,
                        startMin: times.0,
                        endMin: times.1,
                        timeStr: bellStrings[pNum] ?? "",
                        subject: subj,
                        aud: audStr,
                        teacher: teacher,
                        type: pType
                    )
                )
            }
        }
        return list
    }
}

// Виджет компактного формата (Маленький квадрат)
struct ScheduleSmallView: View {
    let entry: ScheduleEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.groupName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .cornerRadius(6)
                
                Spacer()
                
                Text(entry.dayOfWeek)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
            }
            
            Text(entry.statusText)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(entry.isLive ? .green : .blue)
                .lineLimit(1)
                .padding(.top, 2)
            
            if let num = entry.currentNum, !entry.currentSubject.isEmpty {
                Text("\(num) пара")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text(entry.currentSubject)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                if !entry.currentAud.isEmpty {
                    Text(entry.currentAud)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.blue)
                }
            } else if let nextNum = entry.nextNum, !entry.nextSubject.isEmpty {
                Text("След: \(nextNum) пара")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text(entry.nextSubject)
                    .font(.system(size: 12.5, weight: .bold))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                if !entry.nextAud.isEmpty {
                    Text(entry.nextAud)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.blue)
                }
            } else {
                Spacer()
                Text("Занятий нет")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

// Виджет широкого формата (Средняя плашка)
struct ScheduleMediumView: View {
    let entry: ScheduleEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Верхняя плашка с группой, датой и неделей
            HStack {
                Text(entry.groupName)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.blue)
                    .cornerRadius(6)
                
                Text("\(entry.dayOfWeek), \(entry.dateFormatted)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(entry.weekText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(4)
            }
            
            Divider()
            
            // Две колонки: Текущая пара слева, Следующая справа
            HStack(alignment: .top, spacing: 12) {
                // Колонка: Сейчас
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(entry.isLive ? Color.green : Color.blue)
                            .frame(width: 6, height: 6)
                        Text(entry.statusText)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(entry.isLive ? .green : .blue)
                            .lineLimit(1)
                    }
                    
                    if let num = entry.currentNum, !entry.currentSubject.isEmpty {
                        Text("\(num) пара • \(entry.currentTime)")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(entry.currentSubject)
                            .font(.system(size: 12.5, weight: .bold))
                            .lineLimit(2)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            if !entry.currentAud.isEmpty {
                                Text(entry.currentAud)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            if !entry.currentTeacher.isEmpty {
                                Text("• \(entry.currentTeacher)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        Text("Сейчас пары нет")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // Колонка: Далее
                VStack(alignment: .leading, spacing: 2) {
                    Text("Далее")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    if let nextNum = entry.nextNum, !entry.nextSubject.isEmpty {
                        Text("\(nextNum) пара • \(entry.nextTime)")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(entry.nextSubject)
                            .font(.system(size: 12.5, weight: .bold))
                            .lineLimit(2)
                            .foregroundColor(.primary)
                        
                        if !entry.nextAud.isEmpty {
                            Text(entry.nextAud)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    } else {
                        Text(entry.nextStatus.isEmpty ? "Больше пар нет" : entry.nextStatus)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
    }
}

// Главная точка входа виджета
struct ScheduleWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ScheduleEntry

    var body: some View {
        switch family {
        case .systemSmall:
            ScheduleSmallView(entry: entry)
        case .systemMedium:
            ScheduleMediumView(entry: entry)
        default:
            ScheduleMediumView(entry: entry)
        }
    }
}

@main
struct ScheduleWidget: Widget {
    let kind: String = "ScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
            ScheduleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Расписание РИИ")
        .description("Текущие и следующие пары, аудитории и перемены института.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
