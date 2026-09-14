# Скрипт парсинга и генерации базы преподавателей РИИ с rubinst.ru
import urllib.request
import re
import json
import sys
from bs4 import BeautifulSoup
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR))

from services.teacher_service import get_short_name, save_teachers_cache, normalize_phone_display

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

def clean_text(s: str) -> str:
    if not s:
        return ""
    s = re.sub(r"[\ufeff\r\n\t]+", " ", s)
    s = re.sub(r"\s+", " ", s)
    return s.strip()

def fetch_soup(url: str, timeout: int = 15) -> BeautifulSoup:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        html = resp.read().decode("utf-8", errors="ignore")
        return BeautifulSoup(html, "html.parser")

def main():
    print("1. Загрузка педагогического состава со страницы /sveden/employees...")
    teachers = {}
    try:
        soup = fetch_soup("https://www.rubinst.ru/sveden/employees")
        tables = soup.find_all("table")
        print(f"Найдено таблиц: {len(tables)}")
        for table in tables:
            for row in table.find_all("tr"):
                cols = [clean_text(td.get_text()) for td in row.find_all(["td", "th"])]
                if not cols or len(cols) < 2:
                    continue
                name = cols[0]
                if "Ф.И.О" in name or "Фамилия" in name or "ФИО" in name or not name:
                    continue
                parts = name.split()
                if len(parts) < 2:
                    continue

                post = cols[1] if len(cols) > 1 else ""
                disciplines = cols[2] if len(cols) > 2 else ""
                degree = cols[3] if len(cols) > 3 else ""
                title = cols[4] if len(cols) > 4 else ""

                if name not in teachers:
                    teachers[name] = {
                        "full_name": name,
                        "short_name": get_short_name(name),
                        "post": post,
                        "degree": degree,
                        "title": title,
                        "department": "",
                        "disciplines": disciplines,
                        "photo_url": "",
                        "email": "",
                        "phone": "",
                        "room": "",
                        "profile_url": "https://www.rubinst.ru/sveden/employees"
                    }
                else:
                    if post and post not in teachers[name]["post"]:
                        teachers[name]["post"] += f", {post}"
                    if disciplines and disciplines not in teachers[name]["disciplines"]:
                        teachers[name]["disciplines"] += f", {disciplines}"
                    if degree and not teachers[name]["degree"]:
                        teachers[name]["degree"] = degree
                    if title and not teachers[name]["title"]:
                        teachers[name]["title"] = title
    except Exception as e:
        print(f"Ошибка парсинга /sveden/employees: {e}")

    print(f"Собрано преподавателей из таблиц: {len(teachers)}")

    print("2. Загрузка страниц кафедр и подразделений...")
    departments = [
        ("Кафедра Прикладная математика", "https://www.rubinst.ru/department/kafedra-prikladnaya-matematika"),
        ("Кафедра Строительство и механика", "https://www.rubinst.ru/department/kafedra-stroitelstvo-i-mekhanika"),
        ("Кафедра Техника и технологии машиностроения и пищевых производств", "https://www.rubinst.ru/department/kafedra-tekhnika-i-tekhnologii-mashinostroeniya-i-pischevykh-proizvodstv"),
        ("Кафедра Электроэнергетика", "https://www.rubinst.ru/department/kafedra-elektroenergetika"),
        ("Кафедра Гуманитарные дисциплины", "https://www.rubinst.ru/department/kafedra-gumanitarnye-discipliny"),
        ("Кафедра Экономика и управление", "https://www.rubinst.ru/department/kafedra-ekonomika-i-upravlenie"),
        ("Технический факультет", "https://www.rubinst.ru/department/tekhnicheskiy-fakultet"),
        ("Руководство института", "https://www.rubinst.ru/page/administration"),
        ("Руководство", "https://www.rubinst.ru/sveden/managers"),
        ("Ученый совет", "https://www.rubinst.ru/department/uchenyy-sovet"),
    ]

    for dept_name, url in departments:
        try:
            soup = fetch_soup(url)
            # Руководитель подразделения
            rukovoditel_elem = soup.find(class_=re.compile(r"field--name-field-rukovoditel"))
            photo_elem = soup.find(class_=re.compile(r"field--name-field-photo"))
            dolzhnost_elem = soup.find(class_=re.compile(r"field--name-field-dolzhnost"))
            step_elem = soup.find(class_=re.compile(r"field--name-field-leader-step"))
            title_elem = soup.find(class_=re.compile(r"field--name-field-leader-title"))
            phone_elem = soup.find(class_=re.compile(r"field--name-field-phone"))
            email_elems = soup.find_all(class_=re.compile(r"field--name-field-email"))
            room_elem = soup.find(class_=re.compile(r"field--name-field-room-number"))

            if rukovoditel_elem:
                name = clean_text(rukovoditel_elem.get_text())
                photo = ""
                if photo_elem and photo_elem.find("img"):
                    src = photo_elem.find("img").get("src", "")
                    if src.startswith("/"):
                        photo = f"https://www.rubinst.ru{src}"
                    elif src.startswith("http"):
                        photo = src

                emails = [clean_text(e.get_text()) for e in email_elems if clean_text(e.get_text())]
                email_str = ", ".join(emails) if emails else ""
                phone_raw = clean_text(phone_elem.get_text()) if phone_elem else ""
                phone_str = normalize_phone_display(phone_raw)
                room_str = clean_text(room_elem.get_text()) if room_elem else ""
                post_str = clean_text(dolzhnost_elem.get_text()) if dolzhnost_elem else ""
                step_str = clean_text(step_elem.get_text()) if step_elem else ""
                title_str = clean_text(title_elem.get_text()) if title_elem else ""

                # Ищем среди существующих
                found_key = None
                for k in teachers:
                    if k.lower() in name.lower() or name.lower() in k.lower():
                        found_key = k
                        break

                if found_key:
                    if photo:
                        teachers[found_key]["photo_url"] = photo
                    if phone_str:
                        teachers[found_key]["phone"] = phone_str
                    if email_str:
                        teachers[found_key]["email"] = email_str
                    if room_str:
                        teachers[found_key]["room"] = room_str
                    if dept_name and not teachers[found_key]["department"]:
                        teachers[found_key]["department"] = dept_name
                    if post_str and not teachers[found_key]["post"]:
                        teachers[found_key]["post"] = post_str
                    if step_str and not teachers[found_key]["degree"]:
                        teachers[found_key]["degree"] = step_str
                    if title_str and not teachers[found_key]["title"]:
                        teachers[found_key]["title"] = title_str
                    teachers[found_key]["profile_url"] = url
                else:
                    teachers[name] = {
                        "full_name": name,
                        "short_name": get_short_name(name),
                        "post": post_str or "Руководитель",
                        "degree": step_str,
                        "title": title_str,
                        "department": dept_name,
                        "disciplines": "",
                        "photo_url": photo,
                        "email": email_str,
                        "phone": phone_str,
                        "room": room_str,
                        "profile_url": url
                    }

            # Дополнительный поиск фото сотрудников на странице
            for img in soup.find_all("img"):
                alt = clean_text(img.get("alt", ""))
                src = img.get("src", "")
                if alt and len(alt.split()) >= 2 and not any(w in alt.lower() for w in ["лого", "герб", "институт", "знак", "история", "лаборатор", "перечень", "оснащен"]):
                    img_url = f"https://www.rubinst.ru{src}" if src.startswith("/") else src
                    # Сопоставляем alt с преподавателями
                    for k in teachers:
                        if (k.lower() in alt.lower() or alt.lower() in k.lower()) and not teachers[k]["photo_url"]:
                            teachers[k]["photo_url"] = img_url
                            print(f"Найдено фото для {k}: {img_url}")
        except Exception as e:
            print(f"Ошибка парсинга {dept_name}: {e}")

    # 3. Дополнительные сотрудники из расписания
    additional_teachers = [
        {
            "full_name": "Цыганков Андрей Николаевич",
            "post": "Начальник информационно-технического отдела, преподаватель кафедры ПМ",
            "department": "Кафедра Прикладная математика",
            "disciplines": "Информатика, Вычислительные системы и сети",
            "room": "224",
            "profile_url": "https://www.rubinst.ru/department/kafedra-prikladnaya-matematika"
        },
        {
            "full_name": "Гумаров Никита Сергеевич",
            "post": "Преподаватель информатики",
            "department": "Кафедра Прикладная математика",
            "disciplines": "Информатика",
            "room": "221",
            "profile_url": "https://www.rubinst.ru/department/kafedra-prikladnaya-matematika"
        },
        {
            "full_name": "Зыкова Любовь Вячеславовна",
            "post": "Преподаватель кафедры ПМ",
            "department": "Кафедра Прикладная математика",
            "disciplines": "Высшая математика",
            "profile_url": "https://www.rubinst.ru/department/kafedra-prikladnaya-matematika"
        },
        {
            "full_name": "Чугунова Ирина Владимировна",
            "post": "Преподаватель кафедры ЭиУ",
            "department": "Кафедра Экономика и управление",
            "disciplines": "Оценка стоимости бизнеса, Менеджмент",
            "profile_url": "https://www.rubinst.ru/department/kafedra-ekonomika-i-upravlenie"
        },
        {
            "full_name": "Швыдкова Анна Васильевна",
            "post": "Преподаватель, зам. ответственного секретаря приемной комиссии",
            "department": "Технический факультет",
            "phone": "+7 (38557) 5-98-53",
            "profile_url": "https://www.rubinst.ru/structure"
        },
        {
            "full_name": "Кузнецов Владимир Васильевич",
            "post": "Доцент кафедры ГД",
            "department": "Кафедра Гуманитарные дисциплины",
            "disciplines": "Отечественная история, Социология",
            "profile_url": "https://www.rubinst.ru/department/kafedra-gumanitarnye-discipliny"
        }
    ]

    for add in additional_teachers:
        fname = add["full_name"]
        if fname not in teachers:
            teachers[fname] = {
                "full_name": fname,
                "short_name": get_short_name(fname),
                "post": add.get("post", ""),
                "degree": add.get("degree", ""),
                "title": add.get("title", ""),
                "department": add.get("department", ""),
                "disciplines": add.get("disciplines", ""),
                "photo_url": add.get("photo_url", ""),
                "email": add.get("email", ""),
                "phone": add.get("phone", ""),
                "room": add.get("room", ""),
                "profile_url": add.get("profile_url", "https://www.rubinst.ru/structure")
            }
        else:
            for k, v in add.items():
                if v and not teachers[fname].get(k):
                    teachers[fname][k] = v

    print(f"Всего сохранено в базе преподавателей: {len(teachers)}")
    photos_count = sum(1 for t in teachers.values() if t.get("photo_url"))
    print(f"Преподавателей с фото: {photos_count}")

    save_teachers_cache(teachers)
    print("Готово!")

if __name__ == "__main__":
    main()
