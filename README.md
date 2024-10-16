# Superset Deployment

Bu doküman, `deploy.sh` dosyasını indirip çalıştırarak Apache Superset ve PostgreSQL'i Docker ve Docker Compose kullanarak nasıl dağıtacağınızı açıklar.

## Gereksinimler

- Ubuntu 18.04 veya daha yeni bir sürüm

## Kurulum Adımları

1. **`deploy.sh` Dosyasını İndirin:**

    ```bash
    wget https://raw.githubusercontent.com/yapitasi/superset/main/deploy.sh
    ```

2. **`deploy.sh` Dosyasını Çalıştırın:**

    ```bash
    chmod +x deploy.sh
    ./deploy.sh
    ```

## Konfigürasyon

`deploy.sh` dosyası aşağıdaki ortam değişkenlerini ayarlar:

- `POSTGRES_USER`: PostgreSQL kullanıcı adı (varsayılan: `superset`)
- `POSTGRES_PASSWORD`: PostgreSQL şifresi (varsayılan: `**CHANGE_THIS_PASSWORD**`)
- `POSTGRES_DB`: PostgreSQL veritabanı adı (varsayılan: `superset`)
- `SECRET_KEY`: Superset için gizli anahtar (varsayılan: `**CHANGE_THIS_SECRET_KEY**`)

Bu değişkenler `deploy.sh` dosyasında çalıştırmadan önce değiştirilebilir.

## Docker Compose Servisleri

`docker-compose.yml` dosyası aşağıdaki servisleri tanımlar:

- **redis**: Redis önbelleği
- **superset**: Ana Superset uygulaması
- **superset-init**: Superset için başlatma servisi
- **superset-worker**: Superset için Celery işçisi
- **superset-worker-beat**: Superset için Celery beat zamanlayıcısı

## Kullanım

`deploy.sh` dosyasını çalıştırdıktan sonra, Superset uygulaması ve PostgreSQL veritabanı çalışır durumda olacaktır. Superset'e `http://localhost:8088` adresinden erişebilirsiniz.

## Sorun Giderme

Docker konteynerleri başlatılamazsa, logları kontrol edin:

```bash
docker-compose logs