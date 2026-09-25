-- Create in-app notification rows for both sides of an order.
-- The existing Supabase Database Webhook on public.notifications (INSERT)
-- forwards these rows to the send-push Edge Function after commit.

CREATE OR REPLACE FUNCTION public.notify_users_for_new_order_item()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  order_buyer_id uuid;
BEGIN
  SELECT buyer_id
  INTO order_buyer_id
  FROM public.orders
  WHERE id = NEW.order_id;

  IF order_buyer_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.notifications
    WHERE user_id = order_buyer_id
      AND related_order_id = NEW.order_id
      AND type = 'order_placed'
  ) THEN
    INSERT INTO public.notifications (user_id, title, body, type, related_order_id)
    VALUES (
      order_buyer_id,
      'Pesanan berhasil dibuat',
      'Pesananmu sudah diteruskan ke penjual.',
      'order_placed',
      NEW.order_id
    );
  END IF;

  IF NEW.seller_id IS NOT NULL
     AND NEW.seller_id <> order_buyer_id
     AND NOT EXISTS (
       SELECT 1
       FROM public.notifications
       WHERE user_id = NEW.seller_id
         AND related_order_id = NEW.order_id
         AND type = 'order_incoming'
     ) THEN
    INSERT INTO public.notifications (user_id, title, body, type, related_order_id)
    VALUES (
      NEW.seller_id,
      'Pesanan baru masuk',
      'Ada pesanan baru yang perlu kamu proses.',
      'order_incoming',
      NEW.order_id
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_users_for_new_order_item
ON public.order_items;

CREATE TRIGGER notify_users_for_new_order_item
AFTER INSERT ON public.order_items
FOR EACH ROW
EXECUTE FUNCTION public.notify_users_for_new_order_item();
